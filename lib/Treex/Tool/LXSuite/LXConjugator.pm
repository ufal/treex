package Treex::Tool::LXSuite::LXConjugator;
use Moose;
extends 'Treex::Tool::LXSuite::Client';

has '+lxsuite_mode' => (default => 'conjugator');

sub conjugate {
    my ( $self, $lemma, $form, $person, $number ) = @_;
    $self->write("$lemma#$form-$person$number\n");
    return $self->read();
}

1;

__END__

=head1 NAME 

Treex::Tool::Tagger::LXConjugator

=head1 SYNOPSIS

my $conjugator = Treex::Tool::LXSuite::LXConjugator->new();
my $verb = $conjugator->conjugate($verbinf, $flags);

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>
João Rodrigues <joao.rodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
