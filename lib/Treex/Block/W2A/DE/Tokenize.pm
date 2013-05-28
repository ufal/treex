package Treex::Block::W2A::DE::Tokenize;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::W2A::Tokenize';

my $UNBREAKERS = qr{\p{Alpha}|\p{N}+|[IVXLCMDivxlcmd]+| # single letter, numerals    
    
    Adj|Adm|Adv|Asst|Bart|Bldg|Brig|Bros|Capt|Cmdr|Col|Comdr|Con|Corp|Cpl|DR|Dr| # honorifics
    Ens|Gen|Gov|Hon|Hosp|Insp|Lt|MM|MR|MRS|MS|Maj|Messrs|Mlle|Mme|Mr|Mrs|Ms|
    Msgr|Op|Ord|Pfc|Ph|Prof|Pvt|Rep|Reps|Res|Rev|Rt|Sen|Sens|Sfc|Sgt|Sr|St|Supt|
    Surg|
    
    Mio|Mrd|bzw|v|vs|usw|d\.h|z\.B|u\.a|etc|Mrd|MwSt|ggf|d\.J|D\.h|m\.E|vgl| # misc symbols
    I\.F|z\.T|sogen|ff|u\.E|g\.U|g\.g\.A|c\.-à-d|Buchst|u\.s\.w|sog|u\.ä|Std|
    evtl|Zt|Chr|u.U|o\.ä|Ltd|b\.A|z\.Zt|spp|sen|SA|k\.o|jun|i\.H\.v|dgl|dergl|
    Co|zzt|usf|s\.p\.a|Dkr|Corp|bzgl|BSE|
    
    No|Nos|Art|Nr|pp|ca|Ca # number indicators
}xi;

override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;

    # preseve dots in abbreviations by changing them to a weird UTF char
    my $sent2 = $sentence;
    while ( $sentence =~ m/(?:^|\s)($UNBREAKERS)\.(?=\P{Alpha})/g ){
        my $unbr = $1;
        my $mp = pos $sentence;
        
        if ($unbr =~ m/\./){
            $unbr =~ s/\./·/g;
            $sent2 = substr($sent2, 0, $mp-length($unbr)-1) . $unbr . '·' . substr($sent2, $mp);
        }
        else {
            $sent2 = substr($sent2, 0, $mp-1) . '·' . substr($sent2, $mp); 
        }        
    }
    
    # preserve hyphens in coordinated compounds
    $sent2 =~ s/(\p{Alpha})-(\s)/$1‑$2/;
    $sent2 =~ s/(\s)-(\p{Alpha})/$1‑$2/;

    $sentence = $self->SUPER::tokenize_sentence($sent2);

    # get back the dots and hyphens
    $sentence =~ s/·/. /g;
    $sentence =~ s/‑/-/g;

    # clean out extra spaces
    $sentence =~ s/\s+/ /g;
    $sentence =~ s/^\s*//g;
    $sentence =~ s/\s*$//g;

    return $sentence;
};

1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::W2A::DE::Tokenize - rule-based tokenization

=head1 DESCRIPTION

Each sentence is split into a sequence of tokens using a series of regexs.
Flat a-tree is built and attributes C<no_space_after> are filled.

This class uses German specific regex rules (insipred by Tiger/Negra) for tokenization
of abbreviations, ordinal numbers and compounds connected by hyphens (hyphens
and dots will not be separated).

The output is suitable for TreeTagger or Stanford Tagger

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
