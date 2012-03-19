package MultipleSignalHandlers::Destroyer;

sub new {
  my ($class, %args) = @_;
  return bless \(delete $args{signal}), $class;
}

sub DESTROY {
  my ($self) = @_;
  untie($SIG{$$self});
}

1;
