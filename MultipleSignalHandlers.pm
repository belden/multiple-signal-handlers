package MultipleSignalHandlers;

use strict;
use warnings;

use MultipleSignalHandlers::Destroyer;

use overload (
  '&{}' => \&fire_handlers,
  fallback => 1,
);

our $VERSION = 0.04;

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
      my $warn = MultipleSignalHandlers->manage(
        __WARN__ => sub { ... }, # do some custom handling
      );

      # Within the scope of $warn's life, your current handler will get
      called # before the cluck() that we set up above.
    }

    # scope ends, your $SIG{__WARN__} gets restored.

=head1 CONTRACT

I've been there: you need to tamper with the inner workings of some module
you've pulled from CPAN, or you just need to stick extra information
inside its instances.  Private attributes start with a hyphen (-). Play
with them at your own risk.

Handlers are dispatched in LIFO order.

=head1 METHODS

=over 4

=item B<manage>

    my $dispatcher = MultipleSignalHandlers->manage($signal => \&handler);

Takes the name of a signal (a valid key in %SIG), and a coderef to handle
that signal (a valid value in %SIG). Returns a reference to the dispatcher
that gets stored in %SIG.  When the dispatcher for this $signal goes out of
scope, your %SIG reverts to its prior handling for this $signal.

=item B<terminate>

    $SIG{$signal}->terminate;

Stops dispatching this signal to the various listening handlers. The most
useful use I have for this is to generate unique warnings:

    # somewhere
    use Carp qw(cluck);
    local $SIG{__WARN__} = \&cluck;

    # somewhere else, in code you want to quiet down a bit: use
    MultipleSignalHandlers;

    sub generates_warnings_not_sure_why {
      my $dispatcher = MultipleSignalHandlers->manage(
        __WARN__ => sub {
          my ($warning) = @_; $SIG{__WARN__}->terminate if
          $SIG{__WARN__}{-seen}{$warning}++;
        },
      );

      ... stuff that warns ...
    }

=item B<add>

    $dispatcher->add(sub { ... });

Adds a new handler to your existing dispatcher, which will fire before any
existing handlers.

=back

=cut

=head1 AUTHOR

Belden Lyman <belden.lyman@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2011 by Belden Lyman.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
