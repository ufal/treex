package Treex::Block::W2A::ReplaceLemmasWithSynsetId;
use Moose;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    my $synsetid = $anode->wild->{synsetid} // 'UNK';
    if ($synsetid ne 'UNK') {
	$anode->wild->{original_lemma} = $anode->lemma;
        my $alpha_synsetid = "$synsetid";
        $alpha_synsetid =~ tr/0-9/a-j/;
        $anode->set_lemma($alpha_synsetid);
    }  
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::ReplaceLemmasWithSynsetId

=head1 DESCRIPTION

Replaces lemmas with synset ids (where applicable).

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
