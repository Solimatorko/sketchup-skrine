# Dev server for the editor page: serves src/skrine/ui/html with a stub
# `window.sketchup` that talks HTTP to this process. No SketchUp needed.
#   /opt/homebrew/opt/ruby/bin/ruby scripts/ui_server.rb   → http://localhost:8792/
require 'socket'
require 'json'
require 'uri'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

$LOAD_PATH.unshift File.expand_path('../src', __dir__)
require 'skrine/core'

PORT = (ARGV[0] || 8792).to_i
HTML_DIR = File.expand_path('../src/skrine/ui/html', __dir__)
TYPE = Skrine::Core::Registry.fetch(:wardrobe)
TYPES = { '.html' => 'text/html; charset=utf-8', '.js' => 'text/javascript; charset=utf-8', '.css' => 'text/css; charset=utf-8',
          '.json' => 'application/json; charset=utf-8', '.svg' => 'image/svg+xml' }.freeze

STUB = <<~JS
  <script>
  window.sketchup = {
    _call(path, body, then_) { fetch(path, body ? { method: 'POST', body } : {}).then(r => r.json()).then(then_); },
    ready() { this._call('/state', null, p => Skrine.init(p)); },
    preview(json) { this._call('/preview', json, r => Skrine.setPreview(r)); },
    apply(json) { this._call('/preview', json, r => Skrine.setResult({ errors: r.errors, warnings: r.warnings, info: r.info })); },
    gallery() { this._call('/gallery', null, g => Skrine.showGallery(g)); },
    use_preset(file, mode) { this._call('/preset?file=' + encodeURIComponent(file), null, p => Skrine.loadParams(p)); },
    save_named_preset(json, name) { console.log('save_named_preset', name); alert('Uložené (stub): ' + name); },
    save_preset() { alert('save_preset (stub)'); }, load_preset() { alert('load_preset (stub)'); },
    cutlist() { alert('cutlist (stub)'); }, new_object() { alert('new_object (stub)'); }, log(m) { console.log(m); }
  };
  </script>
JS

def respond(sock, status, type, body)
  sock.write("HTTP/1.1 #{status}\r\nContent-Type: #{type}\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n")
  sock.write(body)
end

def json(sock, obj)
  respond(sock, 200, TYPES['.json'], JSON.generate(obj))
end

def handle(sock)
  request = sock.gets or return
  method, target, = request.split(' ')
  headers = {}
  while (line = sock.gets) && line != "\r\n"
    k, v = line.split(':', 2)
    headers[k.downcase] = v.strip
  end
  body = headers['content-length'] ? sock.read(headers['content-length'].to_i) : ''
  uri = URI.parse(target)
  case [method, uri.path]
  when ['GET', '/'], ['GET', '/index.html']
    html = File.read(File.join(HTML_DIR, 'index.html'), encoding: 'UTF-8').sub('<script src="app.js">', "#{STUB}<script src=\"app.js\">")
    respond(sock, 200, TYPES['.html'], html)
  when ['GET', '/state']
    json(sock, Skrine::Editor::PreviewService.init_payload(TYPE, TYPE.schema.defaults))
  when ['POST', '/preview']
    json(sock, Skrine::Editor::PreviewService.preview(TYPE, JSON.parse(body)))
  when ['GET', '/gallery']
    json(sock, Skrine::Editor::PreviewService.gallery(TYPE))
  when ['GET', '/preset']
    file = URI.decode_www_form(uri.query.to_s).to_h['file']
    json(sock, TYPE.schema.merge_defaults(Skrine::Core::PresetStore.read(file)))
  else
    path = File.join(HTML_DIR, File.basename(uri.path))
    if File.file?(path)
      respond(sock, 200, TYPES[File.extname(path)] || 'application/octet-stream', File.binread(path))
    else
      respond(sock, 404, 'text/plain', 'not found')
    end
  end
rescue StandardError => e
  respond(sock, 500, 'text/plain', "#{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
ensure
  sock.close
end

server = TCPServer.new('127.0.0.1', PORT)
puts "Skrine UI dev server: http://localhost:#{PORT}/"
loop { Thread.new(server.accept) { |s| handle(s) } }
