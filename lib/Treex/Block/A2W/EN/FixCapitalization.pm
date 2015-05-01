package Treex::Block::A2W::EN::FixCapitalization;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

my $ALL_CAPS = qr{
    German|English|Turkish|French|Czech|Slovak|Spanish|Portugese|American|Mexican
    Italian|Greek|Serbian|Russian|Chinese|Indian
}xi;


sub process_anode {
    my ($self, $a_node) = @_;
    my $form = $a_node->form // '';

    if ($form =~ /^($ALL_CAPS)$/i ){
        $a_node->set_form(uc(substr($form, 0, 1)) . substr($form, 1));
    }
    return;
}

1;