require 'jekyll/extensions/aop'

def load_jekyll_extensions( source = Dir.pwd )
  exec_path = File.join( Dir.pwd, "_extensions" )
  if File.directory?( exec_path )
  	$stderr.puts "* Load extensions :"
  	Dir.glob( File.join( exec_path, "**", "*.rb" ) ) do |ext|
  		$stderr.puts "  - #{File.basename(ext)}"
  		require ext
  	end
  	puts
  end
end