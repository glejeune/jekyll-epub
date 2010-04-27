module Jekyll
  class EpubBlock < Liquid::Block
    include Liquid::StandardFilters
    
    def initialize(tag_name, markup, tokens)
      super 
    end
    
    def render(context)
      if context.registers[:site].config["epub"]
        super
      else
        ""
      end
    end
  end

  class NoEpubBlock < Liquid::Block
    include Liquid::StandardFilters
    
    def initialize(tag_name, markup, tokens)
      super 
    end
    
    def render(context)
      if context.registers[:site].config["epub"]
        ""
      else
        super
      end
    end
  end
end

Liquid::Template.register_tag('epub', Jekyll::EpubBlock)
Liquid::Template.register_tag('noepub', Jekyll::NoEpubBlock)