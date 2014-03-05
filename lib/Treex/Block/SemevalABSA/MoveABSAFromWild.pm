package Treex::Block::SemevalABSA::MoveABSAFromWild;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    if ($anode->wild->{absa_is_aspect}) {
        my $polarity = $anode->wild->{absa_polarity};
        $polarity =~ s/positive/+/;
        $polarity =~ s/negative/-/;
        $polarity =~ s/neutral/0/;
        $anode->set_form($anode->form . "#ASP#$polarity");
        $anode->set_lemma($anode->lemma . "#ASP#$polarity");

        delete $anode->wild->{absa_polarity};
        delete $anode->wild->{absa_is_aspect};
    }
}

1;
