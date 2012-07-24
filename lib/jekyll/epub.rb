require 'rubygems'
require 'jekyll'
require 'uuid'
require 'mime/types'
require 'jekyll/tags/epub'

module Jekyll
  class StaticFile #:nodoc:
    # This is a Jekyll[http://jekyllrb.com] extension
    #
    # Give the URL of a static file
    def url #:nodoc:
      File.join( @dir, @name )
    end
  end
  
  class Site #:nodoc:    
    def all
      if self.config["epub"]["pages-order"]
        self.create_order( pages.clone, posts.clone, self.config["epub"]["pages-order"], :url )
      else
        posts + pages
      end
    end
    
    def get_item( item, method, posts, pages ) #:nodoc:
      _out = []

      posts.each do |p|
        if p.send(method).gsub( /^\//, "" ) == item
          _out << posts.delete(p)
        end
      end

      pages.each do |p|
        if p.send(method).gsub( /^\//, "" ) == item
          _out << pages.delete(p)
        end
      end

      return _out, posts, pages
    end

    def create_order( pages, posts, order, method ) #:nodoc:
      _result = []
      _order = {}
      order.each do |item|
        if item.class == Symbol
          _order[item] = eval(item.to_s)
        else
          _order[item], posts, pages = get_item( item, method, posts, pages )
        end
      end

      order.each do |item|
        _result = _result + _order[item]
      end

      return _result
    end
    
    # This is a Jekyll[http://jekyllrb.com] extension
    #
    # Same as Site::process but generate the epub. 
    def epub #:nodoc:
      self.reset
      self.read
      
      # Change layout to use epub
      self.layouts.each do |name, layout|
        self.layouts[name].data['layout'] = layout.data['epub'] if layout.data['epub']
      end
      
      # Generate specifics epub files
      FileUtils.rm_rf( self.dest )
      self.package_epub
      
      self.render
      
      # Apply filters
      self.apply_epub_filters( pages )
      self.apply_epub_filters( posts )
      
      self.write
      
      # Create epub file
      self.zip
    end
    
    # This is a Jekyll[http://jekyllrb.com] extension
    #
    # Generate the specifics epub files : content.opf, toc.ncx, mimetype, 
    # page-template.xpgt and META-INF/container.xml
    def package_epub #:nodoc:
      files = []
      order = 0
      
      # Check for cover image
      if self.config["epub"]["cover-image"]
        self.config["epub"]["cover"] = {
          "image" => self.config["epub"]["cover-image"],
          "mime" => MIME::Types.type_for( self.config["epub"]["cover-image"] ).to_s
        }
      end
      
      (all + static_files).each do |p|
        url = p.url.gsub( /^\//, "" )
        next if url == self.config["epub"]["cover-image"]
        mime = MIME::Types.type_for( url ).to_s
        mime = "application/xhtml+xml" if mime == "text/html"     
        next if self.config['exclude'] and self.config['exclude'].include?(File.basename( url ))
        
        if mime == "" then
          $stderr.puts "** Ignore file #{url}, unknown mime type!"
          next
        end
        
        file_data = {
          'id' => url.gsub( /\/|\./, "_" ),
          'url' => url,
          'mime' => mime
        }
        begin
          p.data['layout'] = p.data['epub'] if p.data['epub']
          file_data['title'] = p.data["title"]
          file_data['order'] = order
          order += 1
        rescue => e
          if file_data['mime'] == "text/html"
            $stderr.puts "** Ignore file #{url} : #{e.message}"
            next
          end
        end
        files << file_data
      end
      
      FileUtils.mkdir_p(self.dest)
      FileUtils.mkdir_p(File.join( self.dest, "META-INF" ))
      
      write_epub_file( "content.opf", files )
      write_epub_file( "toc.ncx", files )
      write_epub_file( "mimetype", files )
      write_epub_file( "page-template.xpgt", files )
      write_epub_file( File.join( "META-INF", "container.xml" ) , files )
      if self.config["epub"]["cover-image"]
        write_epub_file( "cover.xhtml", files )
      end
    end
    
    # This is a Jekyll[http://jekyllrb.com] extension
    #
    # Write a specific epub file using Liquid. See Jekyll::Site::package_epub
    def write_epub_file( tmpl, files ) #:nodoc:
      $stderr.puts "** Create #{tmpl}"
      template_file = File.join( File.expand_path( File.dirname( __FILE__ ) ), "epub", "templates", tmpl )
      template_content = Liquid::Template.parse(File.open(template_file).read).render( 'epub' => self.config['epub'], 'files' => files )
      File.open( File.join( self.dest, tmpl ), "w+" ).puts template_content
    end
  
    # This is a Jekyll[http://jekyllrb.com] extension
    #
    # Very simple post-filters
    #
    # This method need to be rewritten and add the possibility to use user's defined filters
    def apply_epub_filters( files ) #:nodoc:
      files.each do |file|
        file.output = file.output.gsub( /(src\s*=\s*['|"])\//, '\1' )
        file.output = file.output.gsub( /(href\s*=\s*['|"])\//, '\1' )

        # Remove all <script> tags
        file.output = file.output.gsub( /<script[^>]*>[^<\/script>]*<\/script>/, "" )
        file.output = file.output.gsub( /<script[^>]*\/>/, "" )
        file.output = file.output.gsub( /<noscript>.*<\/noscript>/, "" )
      end
    end
  
    # This is a Jekyll[http://jekyllrb.com] extension
    #
    # Create the epub file...
    def zip #:nodoc:
      Dir.chdir( self.dest ) do
        filename = self.config['epub']['name']
        filename += ".epub" unless File.extname(filename) == ".epub"
        $stderr.puts "** Create epub file #{filename} in #{Dir.pwd}..."
        %x(zip -X9 \"#{filename}\" mimetype)
        %x(zip -Xr9D \"#{filename}\" * -xi mimetype)
      end
    end
  end
  
  class Epub
    include Jekyll::Filters
    
    DEFAULTS = Jekyll::DEFAULTS.merge( {
      'destination' => File.join('.', '_epub', 'src'),
      'permalink'   => '/:title.html',
      'epub' => {
        'title' => "My Jekyll Blog",
        'language' => 'en',
        'identifier' => UUID.generate
      }
    } )
    
    # Generate a Jekyll::Epub configuration Hash by merging the default options
    # with anything in _epub.yml, and adding the given options on top
    # +override+ is a Hash of config directives
    #
    # Returns Hash
    def self.configuration(override = {})
      # _epub.yml may override default source location, but until
      # then, we need to know where to look for _config.yml
      source = override['source'] || Jekyll::Epub::DEFAULTS['source']

      # Get configuration from <source>/_epub.yml
      config_file = File.join(source, '_epub.yml')
      begin
        config = YAML.load_file(config_file)
        raise "Invalid configuration - #{config_file}" if !config.is_a?(Hash)
        $stdout.puts "** Configuration from #{config_file}"
      rescue => err
        $stderr.puts "** WARNING: Could not read configuration. Using defaults (and options)."
        $stderr.puts "\t" + err.to_s
        config = {}
      end

      # Merge DEFAULTS < _config.yml < override
      Jekyll::Epub::DEFAULTS.deep_merge(config).deep_merge(override)
    end
    
    # Generate the epub! All in one!
    def create( override )
      options = Jekyll::Epub.configuration( override )
      
      site = Jekyll::Site.new(options)
      site.epub
      
      if options['epub']['validate'] == true
        self.validate( site )
      end
    end
    
    # A tiny XHTML validator.
    # 
    # If you want to validate your xhtml files, juste add 
    #
    #  epub:
    #    validate: true
    #
    # in your _epub.yml file.
    def validate( site )
      begin
        require 'xml/libxml'
      rescue => e
        $stderr.puts "** WARNING: libxml-ruby is not installed. Can't validate!"
        return
      end
      
      dtd_file = File.join( File.expand_path( File.dirname( __FILE__ ) ), "epub", "dtd", "xhtml1-strict.dtd" )
      dtd = XML::Dtd.new("-//W3C//DTD XHTML 1.0 Strict//EN", dtd_file)
      
      (site.posts + site.pages).each do |path|
        file = File.join( site.dest, path.url )
        $stderr.puts "** Validate #{file}."
        begin
          doc = XML::Document.file(file)
          doc.validate(dtd)
        rescue => e
          $stderr.puts e.message
        end
      end
    end
    
  end
end
