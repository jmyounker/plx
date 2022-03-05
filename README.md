# Plx a complex of programs

Plx allows you to assemble dispart programs into something behaves like a single program with
nested subcommands. Plx provides the menus and dispatching.

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

And now we have a subcommand:
```
> foo bar commands
car
> foo bar car
you ran car!
>
```
