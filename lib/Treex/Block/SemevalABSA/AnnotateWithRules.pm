package Treex::Block::SemevalABSA::AnnotateWithRules;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    if ($anode->wild->{absa_rules}) {
        $anode->set_form($anode->form . "#RULES#" . $anode->wild->{absa_rules});
        $anode->set_lemma($anode->lemma . "#RULES#" . $anode->wild->{absa_rules});
    }
}

1;
