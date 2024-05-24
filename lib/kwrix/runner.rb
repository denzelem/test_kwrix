module Kwrix
  class Runner

    MODEL = 'gpt-4o'.freeze
    IMAGE_NAME = 'kwrix_image'.freeze
    CONTAINER_NAME = 'kwrix_container'.freeze
    VOLUME_HOST_PATH = Kwrix.root.join('runtime', 'volume').to_s
    VOLUME_CONTAINER_PATH = '/usr/src/app'
    ASSISTANT_NAME = 'Kwrix assistant'.freeze
    ASSISTANT_DESCRIPTION = 'Assistant that uses a docker container for command execution'.freeze
    ASSISTANT_INSTRUCTIONS = <<~TEXT
      You are a bot with a docker container execution environment.
      The Dockerfile has the following content: 
      #{File.read(Kwrix.root.join('runtime', 'Dockerfile'))}

      In case you expect a file, please search for it in the mounted docker volume e.g. image.jpg will be present in #{VOLUME_CONTAINER_PATH}.

      In case you need to create a file, put it into #{VOLUME_CONTAINER_PATH} with a subfolder named with the current date and time. Then output the path for this file on the host machine. The
      host has mounted the volume in #{VOLUME_HOST_PATH}. Example: A file output image.png created on 2001-01-03 at 03:21 should be places in #{VOLUME_CONTAINER_PATH}/20010103-0321 and the user
      should be noticed that the files was put into #{VOLUME_HOST_PATH}/20010103-0321/image.png.

      In case you need to get content of a website, use a appropriate tool within the docker container to fetch these information.
      In case you need access to an API, try to use a free API and talk with it within the docker container.
      In case you need to access the internet directly, use a appropriate tool within the docker container to access the internet.
      In case you need direct access to send emails, use a appropriate tool within the docker container.
    TEXT
    ROLE = 'user'.freeze
    DEBUG = true
    TIMEOUT_IN_SECONDS = 60 * 15
    WAIT_IN_SECONDS = 0.5
    # Limit the tool_output to prevent Rate limit reached for gpt-4o (https://platform.openai.com/settings/organization/limits)
    TOOL_OUTPUT_TRUNCATE_LIMIT = 100

    def initialize
      @client = open_ai_client
      @assistant = open_ai_create_assistant
      @thread_id = open_ai_start_thread
    end

    def run
      build_docker_image
      start_docker_container
      # open_ai_message('Can you convert the flight.jpg to a PNG image?')
      # open_ai_message('I recently visited https://makandra.de/en/our-team-20. Can you help me to name all employees of this company?')
      # open_ai_message('Can you tell me the weather for Augsburg?')
      # open_ai_message('Can you send an email to test@example.com with the subject hello word and the content it works?')
      raise('Uncomment a message below')

      puts open_ai_create_and_retrieve_run # All answers combined
    ensure
      @client.threads.delete(id: @thread_id) if @thread_id.present?
      @client.assistants.delete(id: @assistant['id']) if @assistant['id'].present?
      kwirx_system('docker', 'stop', CONTAINER_NAME)
    end

    private

    def build_docker_image
      kwirx_system('docker', 'build', '--tag', IMAGE_NAME, Kwrix.root.join('runtime').to_s)
    end

    # For testing use: docker run --rm --interactive --tty --name kwrix_container --volume ./runtime/volume:/usr/src/app kwrix bash
    def start_docker_container
      kwirx_system('docker', 'run', '--rm', '--detach', '--tty', '--name', CONTAINER_NAME, '--volume', "#{VOLUME_HOST_PATH}:#{VOLUME_CONTAINER_PATH}", IMAGE_NAME, 'bash')
    end

    def execute_docker_command(command:)
      kwirx_system('docker', 'exec', CONTAINER_NAME, 'bash', '-c', command.to_s)
    end

    def kwirx_system(*command)
      puts "> #{command.join(' ')}" if debug?
      stdout, stderr, status = Open3.capture3(*command, chdir: Kwrix.root)
      status.success?

      if status.success?
        puts stdout if debug?
        stdout
      else
        puts stderr if debug?
        stderr
      end
    end

    def open_ai_client
      OpenAI::Client.new(
        access_token: Configuration.instance.secrets.open_ai_access_token,
        log_errors: debug?,
      )
    end

    def open_ai_create_assistant
      @client.assistants.create(
        parameters: {
          model: MODEL,
          name: ASSISTANT_NAME,
          description: ASSISTANT_DESCRIPTION,
          instructions: ASSISTANT_INSTRUCTIONS,
          tools: [
            { type: 'code_interpreter' },
            {
              type: 'function',
              function: {
                name: 'docker_exec',
                description: 'Execute the given command within the docker container',
                parameters: {
                  type: :object,
                  properties: {
                    command: {
                      type: :string,
                      description: 'The command that needs to be run, e.g. apt update',
                    },
                  },
                  required: ['command'],
                },
              },
            },
          ],
        },
      )
    end

    def open_ai_start_thread
      @client.threads.create['id']
    end

    def open_ai_message(message)
      @client.messages.create(
        thread_id: @thread_id,
        parameters: {
          role: ROLE,
          content: message,
        },
      )
    end

    def open_ai_create_and_retrieve_run
      run_id = @client.runs.create(
        thread_id: @thread_id,
        parameters: {
          assistant_id: @assistant['id'],
        },
      )['id']

      Timeout.timeout(TIMEOUT_IN_SECONDS) do
        loop do
          run = @client.runs.retrieve(id: run_id, thread_id: @thread_id)
          case run.fetch('status')
          when 'queued', 'in_progress', 'cancelling'
            sleep(WAIT_IN_SECONDS)
          when 'requires_action'
            tools = run.dig('required_action', 'submit_tool_outputs', 'tool_calls')

            tool_outputs = tools.map do |tool|
              function_name = tool.dig('function', 'name')
              arguments = JSON.parse(tool.dig('function', 'arguments'), symbolize_names: true)

              tool_output = case function_name
              when 'docker_exec'
                execute_docker_command(**arguments)
              else
                raise ArgumentError, "Unknown function: #{function_name}"
              end

              raise ArgumentError, "Missing tool_output" if tool_output.nil?

              { tool_call_id: tool['id'], output: tool_output.last(TOOL_OUTPUT_TRUNCATE_LIMIT) }
            end

            @client.runs.submit_tool_outputs(
              thread_id: @thread_id,
              run_id: run_id,
              parameters: {
                tool_outputs: tool_outputs,
              },
            )
          when 'completed'
            break @client.messages.list(thread_id: @thread_id).fetch('data').find { |data| data.fetch('role') == 'assistant' }.dig('content', 0, 'text', 'value')
          else
            raise run.inspect.to_s
          end
        end
      end
    end

    def debug?
      DEBUG
    end

  end
end
