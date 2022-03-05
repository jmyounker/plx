# Plx a complex of programs

Plx allows you to assemble dispart programs into something behaves like a single program with
nested subcommands. Plx provides the menus and dispatching.

## Install

`cd` into the project's root and type `make install`:

```
> make install
install -m 0755 plx /usr/local/bin/plx
ln -sf /usr/local/bin/plx /usr/local/bin/plx-sh
>
```

Set `PREFIX` or `BINDIR` to install to another location. Using `PREFIX`:

```
> PREFIX=/usr make install
install -m 0755 plx /usr/bin/plx
ln -sf /usr/bin/plx /usr/bin/plx-sh
>
```

Using `BINDR`:

```
> PREFIX=/tmp make install
install -m 0755 plx /tmp/plx
ln -sf /tmp/plx /tmp/plx-sh
>
```


## Usage

Suppose you want a program that works like the following:

```
> foo
bar
baz
> foo bar
you run bar!
> foo baz
you ran baz!
>
```

So let's build it:
```
> ln -s $(which plx) /usr/local/bin/foo
> print '#!/usr/bin/env bash\necho "you ran bar!"' > /usr/local/bin/foo-bar
> chmod a+x /usr/local/bin/foo-bar
> print '#!/usr/bin/env bash\necho "you ran baz!"' > /usr/local/bin/foo-baz
> chmod a+x /usr/local/bin/foo-baz
>
```

You can also ask for the commands directly:
```
> foo commands
bar
baz
>
```

Suppose you want to add an action for `foo` so that it behaves like this:
```
> foo
you ran foo!
>
```

This is done by adding a default action:
```
> print '#!/usr/bin/env bash\necho "you ran foo!"' > /usr/local/bin/foo-default
> chmod a+x /usr/local/bin/foo-default
>
```

And `foo commands` still works too:
```
> foo
you ran foo!
> foo commands
bar
baz
>
```

### Adding another layer of commands

So let`s extend `foo` with another layer of subcommands. We want to behave like so:
```
> foo bam
car
cod
> foo bam car
you ran car!
> foo bam cod
you ran cod!
>
```

This works just by as with the first example:
```
> ln -s $(which plx) /usr/local/bin/foo-bam
> print '#!/usr/bin/env bash\necho "you ran car!"' > /usr/local/bin/foo-bam-car
> chmod a+x /usr/local/bin/foo-bam-car
> print '#!/usr/bin/env bash\necho "you ran cod!"' > /usr/local/bin/foo-bam-cod
> chmod a+x /usr/local/bin/foo-bam-cod
>
```

And now we can see the subcommands:
```
> foo commands
bam
bar
baz
> foo bam commands
car
cod
> foo bam car
you ran car!
> foo bam cod
you ran cod!
>
```

### Make another level below an existing command

Suppose we want to add a subcommand `car` to `foo bar` from the preceeding examples:

```
> mv /usr/local/bin/foo-bar /usr/local/bin/foo-bar-default
> ln -s $(which plx) /usr/local/bin/foo-bar
> print '#!/usr/bin/env bash\necho "you ran car!"' > /usr/local/bin/foo-bar-car
> chmod a+x /usr/local/bin/foo-bar-car
>
```

And now you have a subcommand:
```
> foo bar commands
car
> foo bar car
you ran car!
>
```

## Building your own menu nodes

Instead of making menus by linking to `plx` you can use `plx-sh` as an interpreter. The simplest
possible replacement for `foo` in the examples above would be the following program:

```
#!/usr/local/bin/plx-sh

plx_run "$@"
```

The bash function `plx_run` implements all the action you've seen. The file's contents are just
a bash script.
