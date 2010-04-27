if RUBY_VERSION >= "1.9"
  require 'continuation'
end

module AOP
  extend self  

  # Intercept the +meth_name+ method of +klass+ and execute +block+ before the
  # original method.
  #   +klass+ Class that method to be intercepted belongs to
  #   +meth_name+ Name of method to be intercepted
  #   +block+ Code to executed before method, and can receive as parameters:
  #     1. the instance that has been intercepted
  #     2. the arguments passed to the original method
  #
  def before(klass, meth_name, &block)
    intercept(klass, meth_name, :before, &block)
  end
  
  # Intercept the +meth_name+ method of +klass+ and execute +block+ after the
  # original method
  #   +klass+ Class that method to be intercepted belongs to
  #   +meth_name+ Name of method to be intercepted
  #   +block+ Code to executed before method, and can receive as parameters:
  #     1. the instance that has been intercepted
  #     2. the arguments passed to the original method
  #
  def after(klass, meth_name, &block)
    intercept(klass, meth_name, :after, &block)
  end
  
  # Intercept the +meth_name+ method of +klass+ and execute +block+ before and
  # after the original method, but needs explicit calling of a Ruby proc/lambda.
  #   +klass+ Class that method to be intercepted belongs to
  #   +meth_name+ Name of method to be intercepted
  #   +block+ Code to executed before method, and can receive as parameters:
  #     1. the instance that has been intercepted
  #     2. the arguments passed to the original method
  #     3. the proc that, if called, will proceed with the execution of the method
  #     4. the proc that, if called, will abort the execution of the method returning
  #        whatever was passed as arguments to the block
  #
  def around(klass, meth_name, &block)
    intercept(klass, meth_name, :around, &block)
  end
  
private
  
  # Use Ruby metaprogramming capabilities to intercept the method only once, making
  # it execute the blocks defined for before, after, and around at the correct
  # time before, after, or around the calling of the original method.
  #   +klass+ Class that method to be intercepted belongs to
  #   +meth_name+ Name of method to be intercepted
  #   +type+ Type of interception to be made (before, after, or around)
  #   +block+ Code to executed before/after/around method
  # 
  def intercept(klass, meth_name, type, &block)
    orig_name = "aop_orig_#{meth_name}".to_sym
    meth_name = meth_name.to_sym
    @intercepted_methods ||= Hash.new do |h,k| 
      # h[class_name] = hash
      h[k] = Hash.new do |h,k|
        # h[class_name][method_name] = hash
        h[k] = Hash.new do |h,k| 
          # h[class_name][method_name][interception_type] = array
          h[k] = []
        end
      end
    end
    
    make_interception = !@intercepted_methods[klass].has_key?(meth_name)
    @intercepted_methods[klass][meth_name][type] << block
    method_chain = @intercepted_methods[klass][meth_name]
    
    if make_interception
      klass.class_eval do
        alias_method orig_name, meth_name
        define_method(meth_name) do |*args|
          method_chain[:before].each { |m| m.call(self, args) }
          # The result of the callcc block will either be the last line in the actual
          # ruby block, or it will be whatever is passed as arguments when calling the 
          # +abort_continuation+ proc
          callcc do |abort_continuation|
            # First lambda in chain is the call to the original method
            call_lambda = lambda { send(orig_name, *args) }
            method_chain[:around].each do |m|
              # Make a chain of lambdas that calls the previouly defined
              # lambda, thus creating a chain of around blocks that will
              # all finally reach the original method block
              prev_call_lambda = call_lambda
              call_lambda = lambda {
                # If +prev_call_lambda+ is called, the next around block in
                # chain until the last one which corresponds to the original method call
                # if +abort_continuation+ is called, then this loop is aborted and the
                # callcc block returns whatever was passed as an argument to the proc call
                m.call(self, args, prev_call_lambda, abort_continuation)
              }
            end
            result = call_lambda.call
            method_chain[:after].each { |m| m.call(self, result, args) }
            result
          end
        end
      end
    end
  end
end