#!/usr/bin/perl

use strict;
use warnings;
use Test::More (tests => 6);

use lib '.';
use MultipleSignalHandlers;

# basic tests
{
  my @fired;

  # a pre-existing signal handler.
  local $SIG{__WARN__} = sub {
    my ($warning) = @_;
    push @fired, ['pre-existing', $warning];
  };

  
  warn("bravo-lima\n");
  is_deeply(\@fired, [['pre-existing', "bravo-lima\n"]], 'sanity: $SIG{__WARN__} being handled.');

  # add a dispatcher to manage multiple handlers on $SIG{__WARN__}
  {
    my $dispatcher = MultipleSignalHandlers->manage(
      __WARN__ => sub {
        my ($warn) = @_;
        push @fired, ['new-handler-1', $warn];
      },
    );

    @fired = ();
    warn("tango-uniform\n");
    is_deeply(\@fired, [
      ['new-handler-1', "tango-uniform\n"],
      ['pre-existing', "tango-uniform\n"],
    ], 'multiple handlers called in the right order');
  }

  # $dispatcher ending scope means we roll back our original signal handling.
  @fired = ();
  warn("uniform-hotel\n");
  is_deeply(\@fired, [['pre-existing', "uniform-hotel\n"]], 'destruction restored original $SIG{__WARN__}');
}

# LIFO order allows you to write signal handlers that terminate signal dispatch, for example
# to produce unique warns only.
{
  local $SIG{__WARN__};

  my @collector;
  $SIG{__WARN__} = sub {
    my ($warn) = @_;
    push @collector, $warn;
  };

  # make 'em unique
  my $dispatcher = MultipleSignalHandlers->manage(
    __WARN__ => sub {
      my ($warn) = @_;
      my $w = $SIG{__WARN__};
      $w->terminate if $w->{seen}{$warn}++;
    },
  );

  warn("alpha-noriega\n");
  warn("tango-delta\n");
  warn("alpha-noriega\n");
  is_deeply(\@collector, ["alpha-noriega\n", "tango-delta\n"], 'handlers can terminate dispatch');
}

# handle $SIG{__DIE__} too
{
  local $SIG{__DIE__};
  my @collector;
  $SIG{__DIE__} = sub { push @collector, @_ };
  my $dont_die = MultipleSignalHandlers->manage(
    __DIE__ => sub { $SIG{__DIE__}->terminate },
  ); 

  local $@;
  eval { die "oh dear" };
  is_deeply(\@collector, [], 'we can handle die');
}

# catch attempts to overwrite our dispatcher
{
  my @order;
  local $SIG{__WARN__} = sub { push @order, 'original' };

  my $warn = MultipleSignalHandlers->manage(
    __WARN__ => sub { push @order, 'handler' },
  );

  $SIG{__WARN__} = sub { push @order, 'overwritten' };

  warn "whisky-foxtrot\n";
  is_deeply(\@order, [qw(overwritten handler original)], "Can't overwrite me");
}
