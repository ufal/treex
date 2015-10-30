package Treex::Block::T2T::RecoverUnknownLemmas;
use Moose;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $src_tnode = $tnode->src_tnode() or return 1;
    return 1 if ($src_tnode->t_lemma ne $tnode->t_lemma);
    my $src_anode = $src_tnode->get_lex_anode() or return 1;
    my $original_lemma = $src_anode->wild->{original_lemma} or return 1;
    $tnode->set_t_lemma($original_lemma);
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::RecoverUnknownLemmas

=head1 DESCRIPTION

Recovers lemmas that have been replaced with synset ids and were not "transferred".

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
