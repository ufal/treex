package Treex::Block::W2A::CS::FixMorphoErrors;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

my %_frequent_abbrevs = (
    'odst' => 'odstavec NNIXX-----A---8',
    'čl'   => 'článek NNIXX-----A---8',
    'písm' => 'písmeno NNIXX-----A---8',
    'věst' => 'věstník NNIXX-----A---8',
    'úř'   => 'úřední AAXXX-----A---8',
);

sub process_anode {
    my ( $self, $anode ) = @_;
    return if ( $anode->is_root );

    my ($new_tag, $new_lemma);

    # treat '%' as a noun abbreviation
    if ( $anode->form eq '%' ){
        $new_tag = 'NNIXX-----A---8';
    }

    # the following rules are weaker: they should not override
    # the tag if the token was already recognized by morphology
    elsif ( $anode->tag =~ /^X/ ) {
        # abbreviations such as DNS, MS-DOS, DVB-T; longer words without dash are probably uppercased unknown words
        if ( $anode->form =~ /^\p{IsUpper}{2,6}(-\p{IsUpper}{1,6})?$/ ) {
            $new_tag = 'NNXXX-----A---8';
        }

        elsif ( $_frequent_abbrevs{ lc($anode->form) } ) {
            ( $new_lemma, $new_tag ) = split / /, $_frequent_abbrevs{ lc($anode->form) };
        }

        # fix the '*', '!' and other signs
        elsif ( $anode->form =~ /^[[:punct:]]$/ ){
            $new_tag = 'Z:-------------';
        }

        # fix Czech decimal numerals
        elsif ( $anode->form =~ /[0-9]+,[0-9]+/ ){
            $new_tag = 'C=-------------';
        }
    }
        
    # a hack for unrecognized lemmas
    elsif ( $anode->lemma eq '-UNKNOWN-' ){
        $new_lemma = lc $anode->form;
    }

    if ( $anode->form =~ /^Obam/ ) {
        # Obamovi set to 3rd case: if it is 6th, a preposition marks this
        # (in Depfix, this means that the case will be fixed later)
        my %obama = ( Obama => 1, Obamy => 2, Obamovi => 3,
            Obamu => 4, Obamo => 5, Obamou => 7 );
        my %obamova = ( Obamová => 1, Obamové => 2, Obamovou => 4);
 
        if ($obamova{$anode->form}) {
            $new_lemma = 'Obamová';
            $new_tag = 'NNFS'.($obamova{$anode->form}).'-----A----';
        } else {
            $new_lemma = 'Obama';
            $new_tag = 'NNMS'.($obama{$anode->form} || 1).'-----A----';
        }
    }

    if ( $new_tag ) {
#        print "form ". $anode->form." oldtag: ".$anode->tag." newtag:$new_tag\n";
        $anode->set_tag($new_tag);
    }

    if ( $new_lemma ) {
#        print "oldlemma: ".$anode->lemma." newlemma:$new_lemma\n";
        $anode->set_lemma($new_lemma);
    }       

    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::CS::FixMorphoErrors

=head1 DESCRIPTION

An attempt to (hopefully temporarily) fix some of the most common current tagger errors:

=over

=item *

Sets the tag 'Z:' for unrecognized punctuation, such as asterisks ("*") and exclamation marks ("!").

=item *

Sets the tag 'NNIXX-----A---8' for percent signs (even though it's marked 'Z:' in Czech National Corpus and PDT), 
since parsing works better with this tag and in an analogous case, the degree sign and the 'Kč' sign get the same tag
(except for gender).

=item *

Sets the tag 'C=' for Czech numbers with decimal comma.

=item * 

Sets the right tag and lemma for some unrecognized frequent Czech abbreviations, such as "čl.", "odst." etc. 
Also sets the abbreviation tag 'NNXXX-----A---8' for unrecognized words composed only of uppercase letters.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>
Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
