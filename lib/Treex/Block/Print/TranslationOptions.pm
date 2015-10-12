package Treex::Block::Print::TranslationOptions;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ( !$tnode->t_lemma or !$tnode->src_tnode ) {
        return;
    }
    my $src_tnode = $tnode->src_tnode;

    # t-lemma
    print { $self->_file_handle } $tnode->id . "\t" . $src_tnode->t_lemma .
        "\t->\t" . $tnode->t_lemma . "\t" . ( $tnode->t_lemma_origin // '' ) . "\n";

    if ( my $t_lemma_vars = $tnode->get_attr('translation_model/t_lemma_variants') ) {
        foreach my $t_lemma_var (@$t_lemma_vars) {
            print "\t\t\t\t" . $t_lemma_var->{t_lemma} . '#' . $t_lemma_var->{'pos'} .
                "\t" . $t_lemma_var->{logprob} . "\n";
        }
    }

    # formeme
    print { $self->_file_handle } $tnode->id . "\t" . $src_tnode->formeme .
        "\t->\t" . $tnode->formeme . "\t" . ( $tnode->formeme_origin // '' ) . "\n";

    if ( my $formeme_vars = $tnode->get_attr('translation_model/formeme_variants') ) {
        foreach my $formeme_var (@$formeme_vars) {
            print "\t\t\t\t" . $formeme_var->{formeme} . "\t" . $formeme_var->{logprob} . "\n";
        }
    }
    return;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Block::Print::TranslationOptions – print translation variants with logprobs

=head1 DESCRIPTION

This can be used for debugging translation on the console – it will print out
the selected translation option (along with origin) as well as all other options
with their logprobs, both for t-lemmas and formemes.

It is recommended to use this after C<Filter::SentenceNumber> to show only the
desired tree (and avoid lengthy console outputs).

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
