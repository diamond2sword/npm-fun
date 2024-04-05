#!/bin/bash

main () (
	declare_strings "$@"
	declare_git_commands
	declare_ssh_auth_eval
	add_ssh_key_to_ssh_agent
	exec_git_command "$@"
)

declare_strings () {
	REPO_NAME="npm-fun"
	BRANCH_NAME="main"
	GH_EMAIL="diamond2sword@gmail.com"
	GH_NAME="diamond2sword"
	DEFAULT_GIT_COMMAND_NAME="push"
	THIS_FILE_NAME="git.bash"
	PROJECT_NAME="project"
	SSH_DIR_NAME=".ssh"
	SSH_KEY_FILE_NAME="id_rsa"
	ROOT_PATH="$HOME"
	REPO_PATH="$ROOT_PATH/$REPO_NAME"
	SSH_TRUE_DIR="$ROOT_PATH/$SSH_DIR_NAME"
	SSH_REPO_DIR="$REPO_PATH/$SSH_DIR_NAME"
	COMMIT_NAME="update project"
	REPO_URL="https://github.com/$GH_NAME/$REPO_NAME"
	SSH_REPO_URL="git@github.com:$GH_NAME/$REPO_NAME"
}

exec_git_command () {
	main () {
		local git_command="$1"; shift
		local args="$*"
		reset_credentials
		if [[ "$git_command" == "git" ]]; then
			ssh_auth_eval "git $args"
			return
		fi	
		eval "$git_command" "$args"
	}

	is_var_set () {
		local git_command="$1"
		! [[ "$git_command" ]] && {
			return
		}
		return 0
	}

	main "$@"
}

declare_git_commands () {
	fix_ahead_commits () {
		cp -r "$REPO_PATH/"* "$REPO_PATH.bak"
		git reset --hard origin/master
		ssh_auth_eval "git fetch"
		cp -r "$REPO_PATH.bak/"* "$REPO_PATH"
		push
	}

	rebase () {
		cd "$REPO_PATH" || return
		ssh_auth_eval "git pull origin $BRANCH_NAME --rebase --autostash"
		ssh_auth_eval "git rebase --continue"
	}

	reset_credentials () {
		cd "$REPO_PATH" || return
		git config --global --unset credential.helper
		git config --system --unset credential.helper
		git config --global user.name "$GH_NAME"
		git config --global user.email "$GH_EMAIL"
	}

	push () {
		cd "$REPO_PATH" || return
		git add .
		git commit -m "$COMMIT_NAME"
		git remote set-url origin "$SSH_REPO_URL"
		ssh_auth_eval "git push -u origin $BRANCH_NAME"
	}

	reclone () {
		rm -r -f "$REPO_PATH"
		mkdir -p "$REPO_PATH"
		cd "$REPO_PATH" || return
		git clone "$REPO_URL" "$REPO_PATH"
	}

	config () {
		local KEY_NAME="$1"
		local NEW_VALUE="$2"
		[[ "$KEY_NAME" == "REPO_NAME" ]] && {
			REPO_NAME="$NEW_VALUE"
		}
		sed -i '{
			/^declare_strings/{
				:start
				/\n\}/!{
					/'"$KEY_NAME"'=/{
						b found
					}
					n
					b start
				}
				b exit
				:found
				/^declare_strings/!{
					s/'"$KEY_NAME"'=.*$/'"$KEY_NAME"'="'"$NEW_VALUE"'"/
				}
			}
			:exit
		}' "$ROOT_PATH/$REPO_NAME/$THIS_FILE_NAME"
	}
}

add_ssh_key_to_ssh_agent () {
	mkdir -p "$SSH_TRUE_DIR"
	cp -f $(eval echo "$SSH_REPO_DIR/"*) "$SSH_TRUE_DIR"
	chmod 600 "$SSH_TRUE_DIR/$SSH_KEY_FILE_NAME"
	eval "$(ssh-agent -s)"
	ssh_auth_eval ssh-add "$SSH_TRUE_DIR/$SSH_KEY_FILE_NAME"
}


declare_ssh_auth_eval () {
eval "$(cat <<- "EOF"
	ssh_auth_eval () {
		command="$@"
		ssh_key_passphrase="$SSH_KEY_PASSPHRASE"
		expect << EOF2
			spawn $command
			expect {
				-re {Enter passphrase for} {
					send "$ssh_key_passphrase\r"
					exp_continue
				}
				-re {Are you sure you want to continue connecting} {
					send "yes\r"
					exp_continue
				}
				eof
			}
		EOF2
	}
EOF
)"
}

main "$@"

