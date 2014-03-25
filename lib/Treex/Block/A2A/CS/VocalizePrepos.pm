package Treex::Block::A2A::CS::VocalizePrepos;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::CS::VocalizePrepos';

use Treex::Tool::Depfix::CS::FixLogger;


my $fixLogger;

sub process_start {
    my $self = shift;
    
    $fixLogger = Treex::Tool::Depfix::CS::FixLogger->new({
        language => $self->language,
    });

    return;
}

sub process_atree {
    my ( $self, $a_root ) = @_;

    my @anodes = $a_root->get_descendants( { ordered => 1 } );

    # we consider bigrams
    foreach my $i ( 0 .. $#anodes - 1 ) {
        if ( $anodes[$i]->tag =~ /^R/ ) {
            my $vocalized = Treex::Block::T2A::CS::VocalizePrepos::vocalize(
                $anodes[$i]->form, $anodes[ $i + 1 ]->form
            );
            if ($anodes[$i]->form ne $vocalized) {
                $fixLogger->logfix1($anodes[$i], "VocalizePrepos");
                $anodes[$i]->set_form($vocalized);
                $fixLogger->logfix2($anodes[$i]);
            }
        }
    }
    return;
}

1;

