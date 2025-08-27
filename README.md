# Kwrix

Kwrix is an example script on how to connect OpenAI to a local docker container interface via function calling.

* Create a file `secrets.yml` in the root directory with your OpenAI API key

```
open_ai_access_token: 'sk-proj-your-token'
```

Examples:

```bash
bundle exec rake clean && cp runtime/fixtures/flight.jpg runtime/volume && bundle exec rake "run[Can you convert the flight.jpg to a PNG image?]"
bundle exec rake "run[I recently visited https://makandra.de/en/our-team-20. Can you help me to name all employees of this company?]"
bundle exec rake "run[Can you tell me the weather for Augsburg?]"
bundle exec rake "run[Can you send an email to test@example.com with the subject hello word and the content it works?]"
```
