require 'rake'
require 'rake/tasklib'
require 'jekyll/epub'

module Jekyll
  class Epub
    class Tasks < ::Rake::TaskLib
      def initialize( &block )
        @_web = { "port" => 4000 }
        @_epub = {}
        
        instance_eval( &block ) if block
        
        @web_override  = Jekyll.configuration( @_web )
        @epub_override = @_epub
        
        define_tasks
      end
      
      def epub( key, value )
        @_epub["epub"][key.to_s] = value
      end
      
      def web( key, value )
        @_web[key.to_s] = value
      end
      
      private
      
      def define_tasks
        desc "Build epub"
        task :epub do
          Jekyll::Epub.new().create( @epub_override )
        end
        
        desc "Build site"
        task :site do
          source      = @web_override['source']
          destination = @web_override['destination']
          site = Jekyll::Site.new(@web_override)
          
          puts "Building site: #{source} -> #{destination}"
          site.process
          puts "Successfully generated site: #{source} -> #{destination}"
        end
        
        desc "Serve site on localhost with port #{@web_override["serve_port"]}"
        task :serve do
          require 'webrick'
          
          FileUtils.mkdir_p( @web_override['destination'] )
          
          mime_types = WEBrick::HTTPUtils::DefaultMimeTypes
          mime_types.store 'js', 'application/javascript'
          
          s = WEBrick::HTTPServer.new(
            :Port            => @web_override['server_port'],
            :DocumentRoot    => @web_override['destination'],
            :MimeTypes       => mime_types
          )
          t = Thread.new {
            s.start
          }
          
          trap("INT") { s.shutdown }
          t.join()
        end
      end
    end
  end
end
