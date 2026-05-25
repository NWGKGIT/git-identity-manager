# git-identity-manager

Switch your Git name, email, and SSH key per repository with a single command.
No manual config editing. No thinking about SSH agents.

```
gituser use work
gituser use personal
```

---

## Install

### Option 1 — One-line install (recommended)

```bash
curl -sSL https://raw.githubusercontent.com/NWGKGIT/git-identity-manager/main/install-remote.sh | bash
```

Then restart your terminal (or `source ~/.bashrc` / `source ~/.zshrc`).

### Option 2 — Clone and install

```bash
git clone https://github.com/NWGKGIT/git-identity-manager.git
cd git-identity-manager
./install.sh
```

Installs to `~/.local/bin` by default (no sudo required).
Use `./install.sh --system` to install to `/usr/local/bin` instead.

### First run

After installing, run the setup wizard:

```bash
gituser init
```

The wizard walks you through creating profiles and optionally generating SSH keys.
You can also run any command (e.g. `gituser use work`) — if no profiles exist,
the wizard starts automatically.

---

## Quick start

```bash
# Create your profiles (interactive wizard)
gituser init

# Switch identity in the current repo
gituser use work
gituser use personal

# Set identity globally (affects all repos without a local override)
gituser use personal --global

# Check what identity is active
gituser status

# Clone a repo and immediately apply a profile
gituser clone git@github.com:org/repo.git --as work
gitclone git@github.com:org/repo.git --as work   # shorthand
```

---

## Command reference

| Command | Description |
|---|---|
| `gituser init` | Run the interactive setup wizard |
| `gituser status` | Show the current Git identity (works inside and outside a repo) |
| `gituser current` | Print the active profile name (useful for shell prompts) |
| `gituser list` | List all saved profiles |
| `gituser use <profile>` | Apply a profile to the current repository |
| `gituser use <profile> --global` | Apply a profile globally |
| `gituser add` | Add a new profile interactively |
| `gituser edit <profile>` | Edit an existing profile |
| `gituser rename <old> <new>` | Rename a profile |
| `gituser remove <profile>` | Delete a profile |
| `gituser clone <url> [dir]` | Clone a repo and select a profile |
| `gituser clone <url> --as <profile>` | Clone and apply a specific profile |
| `gituser doctor` | Check SSH key paths and config health |
| `gituser version` | Print version |
| `gituser help` | Show help |

`gitclone` is a standalone shorthand for `gituser clone`. Both accept identical arguments.

---

## How it works

Each profile stores a Git name, email, and optional SSH key path.
When you run `gituser use <profile>`, it writes to your local `.git/config`:

```ini
[user]
    name  = [First Name] [Last Name]
    email = [email_address]
[core]
    sshCommand = ssh -i ~/.ssh/id_ed25519_work -o IdentitiesOnly=yes
```

Using `--global` writes to `~/.gitconfig` instead.

---

## SSH key setup

If you already have SSH keys, the wizard lets you pick one from a list.

If you do not have a key, the wizard generates one for you:

```
No SSH keys found. Let's generate one.

Email address for the SSH key [you@email.com]: _

Running: ssh-keygen -t ed25519 -C "you@email.com" -f ~/.ssh/id_ed25519_work

[ssh-keygen output]

Public key (~/.ssh/id_ed25519_work.pub):
ssh-ed25519 AAAA... you@email.com

Add this key to your GitHub account:
  https://github.com/settings/ssh/new

Press Enter once the key has been added to GitHub...
```

The `IdentitiesOnly=yes` flag in the generated `sshCommand` ensures that only
the specified key is offered to the remote — preventing key conflicts when you
have multiple identities registered.

---

## Config file format

Profiles are stored in `~/.git-profiles` using INI format.
You do not need to edit this file manually — use the CLI commands.

```ini
[work]
name = [First Name] [Last Name]
email = [email_address]
ssh_key = ~/.ssh/id_ed25519_work

[personal]
name = [First Name] [Last Name]
email = [personal_email_address]
ssh_key = ~/.ssh/id_ed25519_personal
```

Override the config file path with the `GIT_PROFILES` environment variable:

```bash
GIT_PROFILES=/path/to/custom-profiles gituser list
```

---

## Shell prompt integration

The installer automatically adds prompt integration to your `.bashrc` and `.zshrc`. 
When you are inside a Git repository, it will show the active profile in your prompt (e.g., `git:(main) (work)`). 

If you prefer to configure it manually, the command `gituser current` returns ` (profile_name)` when inside a repository. It is extremely fast and designed to run on every prompt draw.

**Manual Bash (`~/.bashrc`)**
```bash
PS1="${PS1}\$(gituser current)"
```

**Manual Zsh (`~/.zshrc`)**
```zsh
setopt prompt_subst
PROMPT="${PROMPT}\$(gituser current)"
```

---

## Shell completion

Shell completions are installed automatically by `install.sh`.
They complete subcommand names and profile names.

| Shell | Status |
|---|---|
| Bash | Supported |
| Zsh  | Supported |
| Fish | Not supported |

### Manual installation

**Zsh** — copy to a directory in your `$fpath`:
```bash
cp completions/_gituser ~/.zsh/completions/_gituser
```

**Bash** — copy to the bash-completion directory:
```bash
cp completions/gituser.bash ~/.local/share/bash-completion/completions/gituser
```

---

## Requirements

- bash 4.0+
- git 2.10+ (for `core.sshCommand` support)
- Linux or macOS

---

## License

MIT