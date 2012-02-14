package Treex::Block::T2T::EN2CS::FixAdjComplAgreement;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ($self, $tnode) = @_;
    
    # just English adjective complements
    return if (!$tnode->src_tnode || (($tnode->src_tnode->formeme || "") !~ /^adj:compl$/));
    
    # Czech adjectives in "za+adj" constructions 
    if (($tnode->formeme || "") =~ /^adj:za\+X$/) {
    #return if ($tnode->src_tnode->formeme =~ /^adj:as\+X$/);

        # get the subject of the parental verb
        my ($subj) = grep {$_->src_tnode && (($_->src_tnode->formeme || "") =~ /^n:subj$/)} $tnode->get_siblings;
        return if (!$subj);

        # if the subject is e.g. a relative pronoun
        my ($ante) = $subj->get_coref_gram_nodes;
        if ($ante) {
            $tnode->set_gram_gender( $ante->gram_gender );
            $tnode->set_gram_number( $ante->gram_number );
        }
        else {
            $tnode->set_gram_gender( $subj->gram_gender );
            $tnode->set_gram_number( $subj->gram_number );
        }
    }

}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::EN2CS::FixAdjComplAgreement

=head1 DESCRIPTION

This blocks fixes the agreement between subject and adjective complement.

For the time being, it is implemented just for adjectives in "za+adj" constructions, e.g.
"the issue is considered serious" -> "problém je považován za závažný"

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
