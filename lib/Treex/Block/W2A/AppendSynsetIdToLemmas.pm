package Treex::Block::W2A::AppendSynsetIdToLemmas;
use Moose;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    my $synsetid = $anode->wild->{lx_wsd} // 'UNK';
    my $lemma = $anode->lemma;
    if ($synsetid ne 'UNK') {
        #my $alpha_synsetid = "$synsetid";
        #$alpha_synsetid =~ tr/0-9/a-j/;
        #$anode->set_lemma($lemma."__".$alpha_synsetid);
        $anode->set_lemma($lemma."__".$synsetid);
    }  
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::AppendSynsetIdToLemmas

=head1 DESCRIPTION

Appends synset ids to lemmas (where applicable).

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
