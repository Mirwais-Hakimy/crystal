{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "closures" do
    it "does closure without args that captures and modifies one local variable" do
      interpret(<<-CODE).should eq(42)
          a = 0
          proc = -> { a = 42 }
          proc.call
          a
        CODE
    end

    it "does closure without args that captures and modifies two local variables" do
      interpret(<<-CODE).should eq(7)
          a = 0
          b = 0
          proc = ->{
            a = 10
            b = 3
          }
          proc.call
          a - b
        CODE
    end

    it "does closure with two args that captures and modifies two local variables" do
      interpret(<<-CODE).should eq(7)
          a = 0
          b = 0
          proc = ->(x : Int32, y : Int32) {
            a = x
            b = y
          }
          proc.call(10, 3)
          a - b
        CODE
    end

    it "does closure and accesses it inside block" do
      interpret(<<-CODE).should eq(42)
          def foo
            yield
          end

          a = 0
          proc = -> { a = 42 }

          x = foo do
            proc.call
            a
          end

          x
        CODE
    end

    it "does closure inside def" do
      interpret(<<-CODE).should eq(42)
          def foo
            a = 0
            proc = -> { a = 42 }
            proc.call
            a
          end

          foo
        CODE
    end

    it "closures def arguments" do
      interpret(<<-CODE).should eq((41 + 1) - (10 + 2))
          def foo(a, b)
            proc = -> { a += 1; b += 2 }
            proc.call
            a - b
          end

          foo(41, 10)
        CODE
    end

    it "does closure inside proc" do
      interpret(<<-CODE).should eq(42)
          proc = ->{
            a = 0
            proc2 = -> { a = 42 }
            proc2.call
            a
          }

          proc.call
        CODE
    end

    it "does closure inside proc, capture proc argument" do
      interpret(<<-CODE).should eq(42)
          proc = ->(a : Int32) {
            proc2 = -> { a += 1 }
            proc2.call
            a
          }

          proc.call(41)
        CODE
    end

    it "does closure inside const" do
      interpret(<<-CODE).should eq(42)
          FOO =
            begin
              a = 0
              proc = -> { a = 42 }
              proc.call
              a
            end

          FOO
        CODE
    end

    it "does closure inside class variable initializer" do
      interpret(<<-CODE).should eq(42)
          class Foo
            @@foo : Int32 =
              begin
                a = 0
                proc = -> { a = 42 }
                proc.call
                a
              end

            def self.foo
              @@foo
            end
          end

          Foo.foo
        CODE
    end

    it "does closure inside block" do
      interpret(<<-CODE).should eq(42)
          def foo
            yield
          end

          foo do
            a = 0
            proc = ->{ a = 42 }
            proc.call
            a
          end
        CODE
    end

    it "does closure inside block, capture block arg" do
      interpret(<<-CODE).should eq(42)
          def foo
            yield 21
          end

          foo do |a|
            proc = ->{ a += 21 }
            proc.call
            a
          end
        CODE
    end

    it "does nested closure inside proc" do
      interpret(<<-CODE).should eq(21)
          a = 0

          proc1 = ->{
            a = 21
            b = 10

            proc2 = ->{
              a += b + 11
            }
          }

          proc2 = proc1.call

          x = a

          proc2.call

          y = a

          y - x
        CODE
    end

    it "does nested closure inside captured blocks" do
      interpret(<<-CODE).should eq(21)
          def capture(&block : -> _)
            block
          end

          a = 0

          proc1 = capture do
            a = 21
            b = 10

            proc2 = capture do
              a += b + 11
            end
          end

          proc2 = proc1.call

          x = a

          proc2.call

          y = a

          y - x
        CODE
    end

    it "does nested closure inside methods and blocks" do
      interpret(<<-CODE).should eq(12)
          def foo
            yield
          end

          a = 0
          proc1 = ->{ a += 10 }

          foo do
            b = 1
            proc2 = ->{ b += a + 1 }

            proc1.call
            proc2.call

            b
          end
        CODE
    end

    it "does closure with pointerof local var" do
      interpret(<<-CODE).should eq(42)
          a = 0
          proc = ->do
            ptr = pointerof(a)
            ptr.value = 42
          end
          proc.call
          a
        CODE
    end

    it "closures self in proc literal" do
      interpret(<<-CODE).should eq(3)
        class Foo
          def initialize
            @x = 1
          end

          def inc
            @x += 1
          end

          def x
            @x
          end

          def closure
            ->{ self.inc }
          end
        end

        foo = Foo.new
        proc = foo.closure
        proc.call
        proc.call
        foo.x
        CODE
    end

    it "closures self in proc literal (implicit self)" do
      interpret(<<-CODE).should eq(3)
        class Foo
          def initialize
            @x = 1
          end

          def inc
            @x += 1
          end

          def x
            @x
          end

          def closure
            ->{ inc }
          end
        end

        foo = Foo.new
        proc = foo.closure
        proc.call
        proc.call
        foo.x
        CODE
    end

    it "closures self and modifies instance var" do
      interpret(<<-CODE).should eq(3)
        class Foo
          def initialize
            @x = 1
          end

          def x
            @x
          end

          def closure
            ->{ @x += 1 }
          end
        end

        foo = Foo.new
        proc = foo.closure
        proc.call
        proc.call
        foo.x
        CODE
    end

    it "closures struct and calls method on it" do
      interpret(<<-CODE).should eq(2)
        struct Foo
          def initialize
            @x = 1
          end

          def inc
            @x += 1
          end

          def x
            @x
          end
        end

        foo = Foo.new
        proc = ->{ foo.inc }
        proc.call
        foo.x
      CODE
    end

    it "doesn't mix local vars with closured vars" do
      interpret(<<-CODE).should eq(20)
        def foo(x)
          yield x
        end

        foo(10) do |i|
          ->{
            a = i
            foo(20) do |i|
              i
            end
          }.call
        end
      CODE
    end

    it "closures closured block arg" do
      interpret(<<-CODE).should eq(1)
        def foo(&block : -> Int32)
          ->{ block.call }.call
        end

        foo do
          1
        end
      CODE
    end

    it "closures block args after 8 bytes (the closure var)" do
      interpret(<<-CODE).should eq(6)
        def foo
          yield({1, 2, 3})
        end

        foo do |x, y, z|
          ->{ x + y + z }.call
        end
      CODE
    end

    it "passes closured struct instance var as self" do
      interpret(<<-CODE).should eq(10)
        struct Bar
          def bar
            10
          end
        end

        class Foo
          def initialize
            @bar = Bar.new
          end

          def foo
            ->{ @bar.bar }.call
          end
        end

        Foo.new.foo
      CODE
    end
  end
end
