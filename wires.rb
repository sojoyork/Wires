require 'tty-prompt'
require 'tty-box'
require 'json'

class WiresTUI
  attr_accessor :blocks, :connections, :variables, :functions

  def initialize
    @prompt = TTY::Prompt.new
    @blocks = []
    @connections = []
    @variables = {}
    @functions = {}
  end

  def add_block
    choices = ["If", "Then", "Not", "Or", "And", "For", "While", "Output <text>", 
               "Run", "Save", "Load", "Define Variable", "Define Function", 
               "Switch", "Return", "Break", "Continue", "Input", "Exit"]
    selection = @prompt.select("Choose a block to add:", choices)
    case selection
    when "If"
      condition = @prompt.ask("Enter the condition (e.g., 'x > 5'):")
      @blocks << { type: "If", condition: condition }
    when "Then"
      action = @prompt.ask("Enter the action (e.g., 'puts x'):")
      @blocks << { type: "Then", action: action }
    when "Switch"
      switch_var = @prompt.ask("Enter the variable to switch on:")
      cases = []
      loop do
        case_value = @prompt.ask("Enter case value (or 'done' to finish):")
        break if case_value.downcase == 'done'
        case_action = @prompt.ask("Enter action for case #{case_value}:")
        cases << { value: case_value, action: case_action }
      end
      @blocks << { type: "Switch", variable: switch_var, cases: cases }
    when "Return"
      return_value = @prompt.ask("Enter the return value:")
      @blocks << { type: "Return", value: return_value }
    when "Break"
      @blocks << { type: "Break" }
    when "Continue"
      @blocks << { type: "Continue" }
    when "Input"
      input_name = @prompt.ask("Enter the input variable name:")
      @blocks << { type: "Input", variable: input_name }
    when "Output <text>"
      text = @prompt.ask("Enter the output message:")
      @blocks << { type: "Output", message: text }
    when "Run"
      run_program
    when "Save"
      save_program
    when "Load"
      load_program
    when "Define Variable"
      define_variable
    when "Define Function"
      define_function
    when "Exit"
      exit
    end
  end

  def define_variable
    var_name = @prompt.ask("Enter the variable name:")
    var_value = @prompt.ask("Enter the value for #{var_name}:")
    @variables[var_name.to_sym] = var_value
    puts "Variable #{var_name} set to #{var_value}."
    sleep(1)
  end

  def define_function
    func_name = @prompt.ask("Enter the function name:")
    func_body = @prompt.ask("Enter the function body (e.g., 'puts \"Hello\"'):")
    @functions[func_name.to_sym] = func_body
    puts "Function #{func_name} defined."
    sleep(1)
  end

  def display_workspace
    system('clear')
    boxes = @blocks.map do |block|
      TTY::Box.frame(width: 20, height: 5, border: :thick, title: {top_left: block[:type]}) do
        case block[:type]
        when "If"
          "Condition: #{block[:condition]}"
        when "Then"
          "Action: #{block[:action]}"
        when "Switch"
          cases = block[:cases].map { |c| "Case #{c[:value]}: #{c[:action]}" }.join("\n")
          "Switch on: #{block[:variable]}\n#{cases}"
        when "Return"
          "Return: #{block[:value]}"
        when "Output"
          "Message: #{block[:message]}"
        when "Input"
          "Input Variable: #{block[:variable]}"
        when "For"
          "Range: #{block[:start]} to #{block[:stop]}"
        when "While"
          "Condition: #{block[:condition]}"
        else
          block[:type]
        end
      end
    end
    boxes.each { |box| puts box }
  end

  def run_program
    puts "\nRunning the program...\n\n"
    x = 0 # A variable for demo purposes
    @blocks.each do |block|
      begin
        case block[:type]
        when "If"
          if eval(replace_variables(block[:condition]))
            puts "If condition met: #{block[:condition]}"
          else
            puts "If condition not met: #{block[:condition]}"
          end
        when "Then"
          eval(replace_variables(block[:action]))
        when "For"
          (block[:start]...block[:stop]).each do |i|
            puts "For loop iteration #{i}"
          end
        when "While"
          while eval(replace_variables(block[:condition]))
            puts "While loop: #{block[:condition]}"
            x += 1 # Example increment to simulate condition change
            break if x > 10 # Example stop condition
          end
        when "Switch"
          switch_value = eval(replace_variables(block[:variable]))
          matched_case = block[:cases].find { |case_block| case_block[:value] == switch_value }
          if matched_case
            eval(replace_variables(matched_case[:action]))
          else
            puts "No matching case for #{switch_value}"
          end
        when "Return"
          puts "Returning value: #{block[:value]}"
        when "Input"
          input_value = @prompt.ask("Enter value for #{block[:variable]}:")
          @variables[block[:variable].to_sym] = input_value
        when "Output"
          puts block[:message]
        when "Break"
          break
        when "Continue"
          next
        end
      rescue => e
        puts "Error: #{e.message}"
      end
    end

    # Execute defined functions
    @functions.each do |name, body|
      puts "Executing function #{name}:"
      begin
        eval(body)  # Executes the function body
      rescue => e
        puts "Error executing function #{name}: #{e.message}"
      end
    end

    # Output done message
    puts "\n========================"
    puts "Output done!"
    puts "Press any key to exit the output page."
    puts "========================"
    STDIN.getch  # Waits for any key press
    system('clear')  # Clears the screen after the key press
  end

  def save_program
    filename = @prompt.ask("Enter the file name to save (without extension):")
    File.open("#{filename}.wires", "w") do |file|
      file.write(JSON.pretty_generate({blocks: @blocks, variables: @variables, functions: @functions}))  # Save all data
    end
    puts "Program saved as #{filename}.wires"
    sleep(1)  # Pause to show the message
  end

  def load_program
    filename = @prompt.ask("Enter the file name to load (without extension):")
    begin
      file_content = File.read("#{filename}.wires")
      data = JSON.parse(file_content, symbolize_names: true)  # Load blocks from the .wires file
      @blocks = data[:blocks]
      @variables = data[:variables]
      @functions = data[:functions]
      puts "Program loaded from #{filename}.wires"
    rescue Errno::ENOENT
      puts "File not found: #{filename}.wires"
    rescue JSON::ParserError
      puts "Error parsing the file: #{filename}.wires"
    end
    sleep(1)  # Pause to show the message
  end

  def replace_variables(expression)
    @variables.each do |name, value|
      expression = expression.gsub(name.to_s, value)  # Replace variable names with their values
    end
    expression
  end

  def run
    loop do
      display_workspace
      add_block
    end
  end
end

# Initialize the TUI and run it
wires_tui = WiresTUI.new
wires_tui.run
