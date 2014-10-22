package Treex::Block::W2A::NL::Tokenize;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::W2A::Tokenize';

# various abbreviations found as un-tokenized in the Alpino corpus
my $UNBREAKERS = qr{\p{Alpha}|\p{N}+|[IVXLCMDivxlcmd]+| # single letter, numerals    
    
    art|Ass|bijv|Burg|ca|Ch|Chr|co|Co|dec|dhr|dr|Dr|drs|Drs|ds|Ds|enz|etc|fa|Gebr|Gld|
    gr|ha|Heidemij|Inc|Int|ir|jhr|jl|jr|kath|Kon|lib|Mc|mej|mevr|mgr|Mij|
    min|mln|mr|Mr|Ned|nl|nom|nov|nr|Olie|pct|Penn|Ph|plm|pnt|prof|ptn|red|resp|
    sec|soc|Sr|St|tel|Th|Uitgeversmij|vacatureE|Ver|Wm|zg|zgn|Zn|
}xi;

override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;

    # preseve dots in abbreviations by changing them to a weird UTF char
    my $sent2 = $sentence;
    while ( $sentence =~ m/(?:^|\s)($UNBREAKERS)\.(?=\P{Alpha})/gi ){
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

Treex::Block::W2A::NL::Tokenize - rule-based tokenization

=head1 DESCRIPTION

Each sentence is split into a sequence of tokens using a series of regexs.
Flat a-tree is built and attributes C<no_space_after> are filled.

This class uses Dutch-specific regex rules for tokenization
of abbreviations, ordinal numbers and compounds connected by hyphens (hyphens
and dots will not be separated).

The output is suitable for Alpino.

The code is derived from the German tokenization block.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
