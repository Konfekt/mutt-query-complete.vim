When using `Vim` as editor for `mutt` (especially with `$edit_headers` set), this plug-in lets you complete names and email addresses using the mutt address_query tool defined by `query_command` (such as [abook](https://github.com/hhirsch/abook), [notmuch-addrlookup](https://github.com/aperezdc/notmuch-addrlookup-c), [mutt_ldap.py](https://github.com/wberrier/mutt-ldap/), [mutt-ldap.pl](https://github.com/namato/dotfiles/blob/e7ce282c8883dd1971356a0ea53c75b47105c8fa/scripts/ldap.pl), ...).

# Usage

When you're editing a mail file in Vim that reads
```
    From: Lu Guanqun <guanqun.lu@gmail.com>
    To:   foo
```
and your query tool has an entry
```
    foo@bar.com Foo Bar
```
and your cursor is right after `foo`, then hit `Ctrl+X Ctrl+O` (which could be remapped, say to `Ctrl-Space`) to obtain:
```
    From: Lu Guanqun <guanqun.lu@gmail.com>
    To:   Foo Bar foo@bar.com
```

# Setup

Completion is enabled in all mail buffers by default.
Add additional file types to the list `g:muttquery_filetypes` which defaults to `[ 'mail' ]`.

The mutt query command is automatically set to the value of the variable `$query_command` used by `mutt`.
To explicitly set the path to a command `$command`, add to your `.vimrc` the line

```vim
  let g:muttquery_command = '$command
```

For example, `$command` could be [`mutt_ldap.py %s`](https://github.com/wberrier/mutt-ldap/).

As a suggestion, if you use different mail accounts with different query commands, add in `.muttrc` a folder hook, say for the account `mailo`,

```
folder-hook '~/.local/share/mbsync/mailo/' 'source "$XDG_CONFIG_HOME/mutt/accounts/mailo"'
```

and in `"$XDG_CONFIG_HOME/mutt/accounts/mailo"` tell Vim about it by

```
set editor = 'vim +"let g:muttquery_command=\"mutt_ldap.py --config \"$XDG_CONFIG_HOME/mutt-ldap/mailo.cfg\" %%s'
```

# Related:

- The [vim-mutt-aliases](https://github.com/Konfekt/vim-mutt-aliases) plug-in lets you complete e-mail addresses in Vim by those in your `mutt` alias file and (when the alias file is periodically populated by the [mutt-alias.sh](https://github.com/Konfekt/mutt-alias.sh) shell script) gives a more static alternative to this plug-in.
(Best run by a, say weekly, [(ana)cronjob](https://konfekt.github.io/blog/2016/12/11/sane-cron-setup).)
- The plugin [vim-notmuch-addrlookup](https://github.com/Konfekt/vim-notmuch-addrlookup) lets you complete e-mail addresses in Vim by those indexed by [notmuch](https://notmuchmail.org).

# License

Distributable under the same terms as Vim itself.  See `:help license`.

