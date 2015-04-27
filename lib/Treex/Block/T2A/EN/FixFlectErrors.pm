package Treex::Block::T2A::EN::FixFlectErrors;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $a_node ) = @_;
    my $form         = $a_node->form         // '';
    my $morphcat_pos = $a_node->morphcat_pos // '';

    if ( $form eq 'badder' ) {
        $a_node->set_form('worse');
    }
    elsif ( $form eq 'halfs' ) {
        $a_node->set_form('half');
    }
    elsif ( $form =~ /^[.,]/ and $form ne ( $a_node->lemma // '' ) ) {
        $a_node->set_form( $a_node->lemma );
    }

    return;
}

1;
