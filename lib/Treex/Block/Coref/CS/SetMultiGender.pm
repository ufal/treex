package Treex::Block::Coref::CS::SetMultiGender;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

my $GENDER_LABEL = {
    F => "fem",
    H => "fem/neut",
    I => "inan",
    M => "anim",
    N => "neut",
    Q => "fem/neut",
    T => "inan/fem",
    X => "anim/inan/fem/neut",
    Y => "anim/inan",
    Z => "anim/inan/neut",
};

sub _ambig_gender {
    my ($tnode) = @_;
    
    my $gender;
    my $anode = $tnode->get_lex_anode;
    if (defined $anode) {
        if ($anode->tag =~ /^PS...(.)/) {
            $gender = $GENDER_LABEL->{$1} // "anim/inan/fem/neut";
        }
        elsif ($anode->tag =~ /^P.(.)/) {
            $gender = $GENDER_LABEL->{$1} // "anim/inan/fem/neut";
        }
        else {
            $gender = "anim/inan/fem/neut";
        }
    }
    else {
        $gender = "anim/inan/fem/neut";
    }
    return $gender;
}

sub process_tnode {
    my ($self, $tnode) = @_;

    # apply only to semantic nouns
    return if (!defined $tnode->gram_sempos || $tnode->gram_sempos !~ /^n/);

    my $gender;

    # dropped subject pronouns
    if (defined $tnode->wild->{'aux_gram/gender'}) {
        $gender = $tnode->wild->{'aux_gram/gender'};
    }
    # possessive pronouns (personal, reflexive, relative) - take the possessor's gender instead
    #elsif () {
    #}
    # already disambiguated non-possessive pronouns
    elsif (defined $tnode->gram_gender && $tnode->gram_gender ne "nr" && $tnode->gram_gender ne "inher") {
        $gender = $tnode->gram_gender;
        my $anode = $tnode->get_lex_anode;
        my $form_tag = defined $anode ? $anode->form . "\t" . $anode->tag . "\t" . $gender : "_\t_\t_";
        #print STDERR "DISAMBIG GENDERS: $form_tag\n";
        #$gender = _ambig_gender($tnode);
    }
    # ambiguous non-possessive pronouns
    else {
        $gender = _ambig_gender($tnode);
    }
    
    $tnode->wild->{'multi_gram/gender'} = $gender;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Coref::CS::SetMultiGender

=head1 DESCRIPTION

Sets an alternative to a tecto gender grammateme into wild->{'multi_gram/gender'}.
Several possible values delimited by '/' are possible.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
