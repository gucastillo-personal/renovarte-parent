#!/usr/bin/env ruby
# frozen_string_literal: true

# docs-check — valida la base de conocimiento de renovarte-parent (solo lectura).
#
# Chequea links relativos, wikilinks, frontmatter de ADRs y specs, la
# consistencia de manifest.yaml con las notas de docs/, las relaciones de
# supersede, el índice de ADRs y que no se publiquen IDs de cuenta AWS ni
# URLs de webhooks. Usa solo la biblioteca estándar de Ruby: no instala nada.
#
# Uso: make docs-check   (o ruby scripts/docs-check.rb desde la raíz)
# Sale con código 1 si hay errores. Las advertencias no fallan: cubren
# referencias a submódulos sin inicializar o a repos todavía `planned`.

require 'yaml'
require 'date'
require 'set'

ROOT = File.expand_path('..', __dir__)
Dir.chdir(ROOT)

MANIFEST = YAML.safe_load(File.read('manifest.yaml'), permitted_classes: [Date])
REPOS = MANIFEST.fetch('repositories')
SUBMODULE_DIRS = REPOS.values.map { |r| r['path'] }.compact

ADR_STATUSES = %w[Proposed Accepted Superseded Deprecated].freeze
ADR_LEVELS = %w[L2 L3].freeze
REVERSIBILITY = %w[baja media alta].freeze
ADR_KEYS = %w[id title status date deciders level repos domains providers origin
              supersedes extends superseded_by constitution cost_impact
              personal_data reversibility retroactive detail].freeze
ADR_SECTIONS = ['## Contexto', '## Decisión', '## Alternativas consideradas',
                '## Notas posteriores'].freeze
SPEC_STATUSES = %w[draft design approved implementing done done-with-debt abandoned].freeze
SPEC_KEYS = %w[id title type status created repos domains contracts providers decisions].freeze
REPO_STATUSES = %w[planned in-development production retired].freeze

# Patrones que no pueden aparecer en docs públicos.
LEAKS = {
  'ID de cuenta AWS en un ARN' => /arn:aws:[a-z0-9-]+:[a-z0-9-]*:\d{12}:/,
  'ID de cuenta AWS en una URL' => %r{amazonaws\.com/\d{12}/},
  'URL de webhook de Discord' => %r{discord(?:app)?\.com/api/webhooks/\d+/}
}.freeze

@errors = []
@warnings = []

def error(file, msg)
  @errors << "#{file}: #{msg}"
end

def warn_(file, msg)
  @warnings << "#{file}: #{msg}"
end

# --- archivos del vault (sin los submódulos) ---------------------------------

def vault_files(pattern)
  Dir.glob(pattern, File::FNM_DOTMATCH).reject do |f|
    SUBMODULE_DIRS.any? { |d| f == d || f.start_with?("#{d}/") } || f.include?('/.git/')
  end.sort
end

MD_FILES = vault_files('{*.md,docs/**/*.md,specs/**/*.md,.claude/**/*.md}')
NOTE_NAMES = Set.new(MD_FILES.map { |f| File.basename(f, '.md') } +
                     MD_FILES.map { |f| f.sub(/\.md\z/, '') })

def split_frontmatter(text)
  return [nil, text] unless text.start_with?("---\n")

  close = text.index("\n---", 4)
  return [nil, text] unless close

  yaml = text[4...close]
  body = text[(close + 4)..] || ''
  [YAML.safe_load(yaml, permitted_classes: [Date]), body]
rescue Psych::SyntaxError => e
  [{ '__error__' => e.message }, text]
end

# Saca bloques de código y código inline: ahí viven ejemplos y placeholders.
def strip_code(text)
  text.gsub(/^```.*?^```/m, '').gsub(/`[^`\n]*`/, '')
end

def wikilinks(value)
  case value
  when String then value.scan(/\[\[([^\]]+)\]\]/).flatten.map { |w| w.split(/[|#]/).first.strip }
  when Array then value.flat_map { |v| wikilinks(v) }
  when Hash then value.values.flat_map { |v| wikilinks(v) }
  else []
  end
end

def submodule_uninitialized?(path)
  dir = SUBMODULE_DIRS.find { |d| path == d || path.start_with?("#{d}/") }
  dir && (!Dir.exist?(dir) || Dir.empty?(dir))
end

def planned_repo_path?(path)
  REPOS.any? { |_, r| r['status'] == 'planned' && path.start_with?("#{r['path']}/") }
end

# --- 1. links relativos y wikilinks ------------------------------------------

def check_links
  MD_FILES.each do |f|
    next if File.basename(f) == '_template.md'

    text = File.read(f)
    fm, = split_frontmatter(text)
    body = strip_code(text)

    body.scan(/\]\(([^)\s]+)\)/).flatten.each do |link|
      next if link.match?(%r{\A(?:[a-z]+:|#|/)})

      target = File.expand_path(link.split('#').first, File.dirname(f))
      rel = target.sub("#{ROOT}/", '')
      next if File.exist?(target)

      if submodule_uninitialized?(rel)
        warn_(f, "link a un submódulo sin inicializar: #{link}")
      else
        error(f, "link roto: #{link}")
      end
    end

    names = wikilinks(fm.is_a?(Hash) ? fm.reject { |k, _| k == '__error__' } : nil) +
            body.scan(/\[\[([^\]]+)\]\]/).flatten.map { |w| w.split(/[|#]/).first.strip }
    names.uniq.each do |name|
      next if NOTE_NAMES.include?(name)

      spec_dir = name[%r{\Aspecs/\d{4}-[^/]+}]
      if spec_dir && !Dir.exist?(spec_dir)
        # La spec vive en una rama que todavía no se mergeó (ej. 0017).
        warn_(f, "wikilink a una spec que no está en este checkout: [[#{name}]]")
      else
        error(f, "wikilink sin nota: [[#{name}]]")
      end
    end
  end
end

# --- 2. ADRs -----------------------------------------------------------------

def adr_id(ref)
  ref.to_s[/ADR-\d{4}/]
end

def check_adrs
  files = vault_files('docs/decisions/ADR-*.md')
  adrs = {}
  files.each do |f|
    fm, body = split_frontmatter(File.read(f))
    if fm.nil? || fm['__error__']
      error(f, "frontmatter ausente o inválido #{fm && fm['__error__']}")
      next
    end
    id = File.basename(f)[/\AADR-\d{4}/]
    adrs[id] = { file: f, fm: fm }

    (ADR_KEYS - fm.keys).each { |k| error(f, "falta el campo `#{k}`") }
    error(f, "id `#{fm['id']}` no coincide con el nombre del archivo") if fm['id'] != id
    error(f, "status inválido: #{fm['status']}") unless ADR_STATUSES.include?(fm['status'])
    error(f, "level inválido: #{fm['level']}") unless ADR_LEVELS.include?(fm['level'])
    error(f, "reversibility inválida: #{fm['reversibility']}") unless REVERSIBILITY.include?(fm['reversibility'])
    ADR_SECTIONS.each { |s| error(f, "falta la sección `#{s}`") unless body.include?("\n#{s}") }
  end

  adrs.each do |id, a|
    fm = a[:fm]
    sup_by = adr_id(fm['superseded_by'])
    if fm['status'] == 'Superseded'
      if sup_by.nil?
        error(a[:file], 'está Superseded pero no tiene `superseded_by`')
      elsif !adrs[sup_by]
        error(a[:file], "superseded_by apunta a #{sup_by}, que no existe")
      elsif !Array(adrs[sup_by][:fm]['supersedes']).map { |s| adr_id(s) }.include?(id)
        error(a[:file], "#{sup_by} no lo lista en `supersedes`")
      end
    elsif sup_by
      error(a[:file], "tiene superseded_by #{sup_by} pero su status es #{fm['status']}")
    end

    Array(fm['supersedes']).map { |s| adr_id(s) }.each do |old|
      if !adrs[old]
        error(a[:file], "supersedes #{old}, que no existe")
      elsif adrs[old][:fm]['status'] != 'Superseded' || adr_id(adrs[old][:fm]['superseded_by']) != id
        error(a[:file], "supersedes #{old}, pero #{old} no está Superseded por #{id}")
      end
    end
  end

  index = File.read('docs/decisions/README.md')
  adrs.each do |id, a|
    row = index.lines.find { |l| l.start_with?("| [#{id}](./#{File.basename(a[:file])})") }
    if row.nil?
      error('docs/decisions/README.md', "#{id} no está en el índice (o el link no coincide con el archivo)")
    elsif !row.split('|')[4].to_s.strip.start_with?(a[:fm]['status'])
      error('docs/decisions/README.md', "#{id}: el estado del índice no coincide con el ADR (#{a[:fm]['status']})")
    end
  end
  adrs
end

# --- 3. specs ----------------------------------------------------------------

def check_specs(adrs)
  Dir.glob('specs/*/').sort.each do |dir|
    candidates = Dir.glob("#{dir}*.md").sort
    spec = candidates.find { |f| File.basename(f) == 'spec.md' } ||
           candidates.find { |f| (split_frontmatter(File.read(f)).first || {})['type'] == 'spec' }
    if spec.nil?
      error(dir, 'no tiene spec.md ni un documento con frontmatter `type: spec`')
      next
    end

    fm, body = split_frontmatter(File.read(spec))
    if fm.nil? || fm['__error__']
      error(spec, "frontmatter ausente o inválido #{fm && fm['__error__']}")
      next
    end
    (SPEC_KEYS - fm.keys).each { |k| error(spec, "falta el campo `#{k}`") }
    error(spec, "id debe ser un string entre comillas: #{fm['id'].inspect}") unless fm['id'].is_a?(String)
    error(spec, "id #{fm['id']} no coincide con la carpeta") unless dir.include?("/#{fm['id']}-")
    error(spec, "type debe ser `spec`, no #{fm['type'].inspect}") unless fm['type'] == 'spec'
    error(spec, "status inválido: #{fm['status']}") unless SPEC_STATUSES.include?(fm['status'])

    fm_adrs = Array(fm['decisions']).map { |d| adr_id(d) }.compact
    fm_adrs.each { |d| error(spec, "decisions lista #{d}, que no existe") unless adrs[d] }

    section = body[/^## Decisiones relacionadas\n(.*?)(?=^## |\z)/m, 1]
    if section.nil?
      error(spec, 'falta la sección `## Decisiones relacionadas`')
    else
      listed = section.lines.select { |l| l.start_with?('- ') }.map { |l| adr_id(l) }.compact
      unless listed.sort == fm_adrs.sort
        error(spec, "`## Decisiones relacionadas` (#{listed.sort.join(', ')}) no coincide con " \
                    "`decisions` del frontmatter (#{fm_adrs.sort.join(', ')})")
      end
    end
  end
end

# --- 4. manifest ↔ notas -----------------------------------------------------

def check_note(kind, name, owner)
  path = "docs/#{kind}s/#{kind}-#{name}.md"
  error('manifest.yaml', "#{owner}: falta la nota #{path}") unless File.exist?(path)
end

def check_manifest(adrs)
  providers = MANIFEST.fetch('providers').keys
  contracts = MANIFEST.fetch('contracts')

  REPOS.each do |name, r|
    owner = "repositories.#{name}"
    check_note('repo', name, owner)
    error('manifest.yaml', "#{owner}: status inválido #{r['status']}") unless REPO_STATUSES.include?(r['status'])
    if r['status'] != 'planned' && !Dir.exist?(r['path'].to_s)
      error('manifest.yaml', "#{owner}: path `#{r['path']}` no existe")
    end
    Array(r['domains']).each { |d| check_note('domain', d, owner) }
    Array(r['providers']).each do |p|
      error('manifest.yaml', "#{owner}: proveedor `#{p}` no está en `providers`") unless providers.include?(p)
    end
    Array(r['foundational_decisions']).each do |d|
      error('manifest.yaml', "#{owner}: #{d} no existe en docs/decisions/") unless adrs[d]
    end
  end

  contracts.each do |name, c|
    owner = "contracts.#{name}"
    check_note('contract', name, owner)
    ([c['producer']] + Array(c['consumers']&.keys)).compact.each do |repo|
      error('manifest.yaml', "#{owner}: `#{repo}` no está en `repositories`") unless REPOS.key?(repo)
    end
    schema = c['schema'].to_s.split('#').first
    next if schema.empty? || File.exist?(schema)

    producer_planned = REPOS.dig(c['producer'], 'status') == 'planned'
    if producer_planned || submodule_uninitialized?(schema) || planned_repo_path?(schema)
      warn_('manifest.yaml', "#{owner}: el schema `#{schema}` no está en este checkout (productor planned o submódulo sin inicializar)")
    else
      error('manifest.yaml', "#{owner}: el schema `#{schema}` no existe")
    end
  end

  providers.each { |p| check_note('provider', p, "providers.#{p}") }

  { 'repo' => REPOS.keys, 'domain' => REPOS.values.flat_map { |r| Array(r['domains']) },
    'contract' => contracts.keys, 'provider' => providers }.each do |kind, names|
    vault_files("docs/#{kind}s/#{kind}-*.md").each do |f|
      name = File.basename(f, '.md').delete_prefix("#{kind}-")
      error(f, "no hay `#{name}` en manifest.yaml (nota huérfana)") unless names.include?(name)
    end
  end
end

# --- 5. datos que no se publican ---------------------------------------------

def check_leaks
  (MD_FILES + ['manifest.yaml']).each do |f|
    File.read(f).each_line.with_index(1) do |line, n|
      LEAKS.each { |what, re| error("#{f}:#{n}", what) if line.match?(re) }
    end
  end
end

# --- main --------------------------------------------------------------------

check_links
adrs = check_adrs
check_specs(adrs)
check_manifest(adrs)
check_leaks

@warnings.each { |w| puts "⚠ #{w}" }
@errors.each { |e| puts "✗ #{e}" }
puts "docs-check: #{MD_FILES.size} archivos, #{adrs.size} ADRs — " \
     "#{@errors.size} errores, #{@warnings.size} advertencias"
exit(@errors.empty? ? 0 : 1)
