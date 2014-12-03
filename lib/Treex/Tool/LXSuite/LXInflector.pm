package Treex::Tool::LXSuite::LXInflector
use Moose;
extends 'Treex::Tool::LXSuite::Client';

has '+lxsuite_mode' => (default => 'inflector');

sub inflect {
    my ( $self, $lemma, $pos, $gender, $number ) = @_;
    $self->write("$lemma,$pos,$gender,$number\n");
    $result = $self->read();
    return $result;
}

1;

__END__

=head1 NAME 

Treex::Tool::Tagger::LXInflector

=head1 SYNOPSIS

my $inflector = Treex::Tool::LXSuite::LXInflector->new();
my $form = $inflector->inflect($lemma, $pos, $gender, $number);

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>
João Rodrigues <joao.rodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
