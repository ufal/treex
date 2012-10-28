package Treex::Block::A2A::CS::VocalizePrepos;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::CS::VocalizePrepos';

sub process_atree {
    my ( $self, $a_root ) = @_;

    my @anodes = $a_root->get_descendants( { ordered => 1 } );

    # we consider bigrams
    foreach my $i ( 0 .. $#anodes - 1 ) {
        if ( $anodes[$i]->tag =~ /^R/ ) {
            my $vocalized = Treex::Block::T2A::CS::VocalizePrepos::vocalize(
                $anodes[$i]->form, $anodes[ $i + 1 ]->form
            );
            $anodes[$i]->set_form($vocalized);
        }
    }
    return;
}
