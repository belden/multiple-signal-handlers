package MultipleSignalHandlers;

use strict;
use warnings;

use MultipleSignalHandlers::Destroyer;

use overload (
  '&{}' => \&fire_handlers,
  fallback => 1,
);

our $VERSION = 0.05;

sub TIESCALAR {
  my ($class, %args) = @_;

  my $default = delete $args{default};

  my $self = +{
    -default => $default,
    -handlers => [$default],
    -signal => $args{signal},
    -terminated => 0,
  };
  return bless $self, $class;
}

sub FETCH { shift }

sub STORE {
  my ($self, $val) = @_;
  $self->add($val);
}

sub UNTIE {
  my ($self, $count) = @_;
  $self->DESTROY;
}

sub manage {
  my ($class, $signal, $handler) = @_;

  if (!UNIVERSAL::isa($SIG{$signal}, $class)) {
    my $existing = delete $SIG{$signal};
    tie $SIG{$signal}, $class, (default => $existing, signal => $signal);
  }

  $SIG{$signal} = $handler;
  return MultipleSignalHandlers::Destroyer->new(signal => $signal);
}

sub add {
  my ($self, $handler) = @_;
  unshift @{$self->{-handlers}}, $handler;
}

sub fire_handlers {
  my ($self) = @_;
  return sub {
    local $self->{-terminated};
    foreach ($self->handlers) {
      last if $self->{-terminated};
      $_->(@_);
    }
  };
}

sub terminate { shift->{-terminated} = 1 }
sub handlers { @{shift->{-handlers}} }

sub DESTROY {
  my ($self) = @_;
  $SIG{$self->{-signal}} = $self->{-default};
}

1;

__END__

=head1 NAME

MultipleSignalHandlers - Attach multiple handlers to the same signal.

=head1 SYNOPSIS

  use Carp qw(cluck);
  $SIG{_WARN__} = \&cluck;

  {
    my $restore = MultipleSignalHandlers->manage(
      __WARN__ => sub { ... }, # do some custom handling
    );

    # Within the scope of $warn's life, your current handler
    # will get called before the cluck() that's originally
    # handling $SIG{__WARN__}.

  }

  # scope ends, your $SIG{__WARN__} handler gets restored to
  # plain old \&cluck.

=head1 METHODS

=head2 B<manage>

  my $destroyer = MultipleSignalHandlers->manage(
    $signal => \&handler,
  );

Takes the name of a signal (a valid key in %SIG), and a coderef to
handle that signal (a valid value in %SIG).

coderefs will be called as any normal signal handler in Perl.
See the discussion of Signals in L<perlipc|perlipc>.

Returns a reference to a destroyer for the dispatcher that gets stored
in %SIG. When the destroyer for this $signal goes out of scope, %SIG
reverts to its prior handling for this $signal.

=head2 B<terminate>

  $SIG{$signal}->terminate;

Stops dispatching this signal to the various listening handlers. The
most useful use I have for this is to generate unique warnings:

  # somewhere
  use Carp qw(cluck);
  local $SIG{__WARN__} = \&cluck;

  # somewhere else, in code you want to quiet down a bit:
  use MultipleSignalHandlers;

  sub generates_warnings_not_sure_why {
    my $restore_sig_warn = MultipleSignalHandlers->manage(
      __WARN__ => sub {
        my ($warning) = @_;
        $SIG{__WARN__}->terminate if $SIG{__WARN__}{seen}{$warning}++;
      },
    );

    ... stuff that warns ...
  }

=head2 B<add>

  $SIG{...}->add(sub { ... });
  $SIG{...} = sub { ... };

Adds a new handler to your existing dispatcher, which will fire
before any existing handlers.

=head1 CONTRACT

I've been there: you need to tamper with the inner workings of some
module you've pulled from CPAN, or you just need to stick extra
information inside its instances.  Private attributes start with a
hyphen (-). Play with them at your own risk.

Handlers are dispatched in LIFO order.


=head1 REASSIGNMENT TO $SIG{...}

Once you have set up a dispatcher to manage multiple handlers for a
given signal, the dispatcher will catch this:

  $SIG{$your_signal} = \&new_handler;

and treat it as this:

  $SIG{$your_signal}->add(\&new_handler);

That is to say, the dispatcher will continue to exist, and will fire
new_handler() before firing other handlers that the dispatcher
already knows about.

However, if you do this:

  local $SIG{$your_signal} = \&new_handler;

then the rules of local() kick in, and you won't get multiple dispatch
until the scope of your local() ends.

=head1 AUTHOR

Belden Lyman <belden.lyman@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2011 by Belden Lyman.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. The github repository for
this module is: git://github.com/belden/multiple-signal-handlers.git

=cut
