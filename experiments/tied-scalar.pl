#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
  package wth;
  sub TIESCALAR {
    my ($class, %args) = @_;
    return bless +{
      foo => 'bar',
      locked => 0,
      %args,
    }, $class;
  }

  sub new {
    my ($class, %args) = @_;
    my $self;
    tie $self, $class, %args;
    return $self;
  }

  sub lockem {
    my ($self) = @_;
    if ($self->{locked}) {
      print "...unlocking from $self->{foo}\n";
      $self->{locked} = 0;
    } else {
      print "...locking at $self->{foo}\n";
      $self->{locked} = 1;
    }
  }
    
  sub STORE {
    my ($self, $val) = @_;
    if ($self->{locked}) {
      print "...rejecting $val, locked at $self->{foo}\n";
    } else {
      print "...setting $val\n";
      $self->{foo} = $val;
    }
  }
  sub FETCH {
    my ($self) = @_;
    return $self->{foo};
  }
  sub UNTIE {
    my ($self) = @_;
  }
  sub DESTROY {
  }
}

my $wth;
tie $wth, 'wth';
foreach (1..10) {
  $wth = $_;
  if (rand() > .2) {
    tied($wth)->lockem;
  }
}
