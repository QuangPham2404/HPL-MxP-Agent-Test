# Extra instructions for agents for this directory

About the structure:
- `README.md` is used to details the debugging plan. User will instruct the agent manually on what test they want to run for debugging based on this file.
- `debug-scripts/` is the place to store all the scripts in this debug process.
- `outputs/` is where to store all of the output files from jobs.
- `DEBUG_PROGRESS.md` is the file that records the results, analysis from test/phases AND next steps based on analysis. Throughout the session, the user will instruct the agent to update this file accordingly. When user ends the session and ask agent to write progress.md as per workflow, check if this file is already updated. If yes, proceed with the normal progress.md file. If not, update accordingly based on progress in that session.

When starting a debug session in this directory, read `README.md` and `DEBUG_PROGRESS.md` to know the context before continue.