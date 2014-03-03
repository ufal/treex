package Treex::Tool::Depfix::CS::FormGenerator;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Tool::Depfix::FormGenerator';

use LanguageModel::MorphoLM;
use Treex::Tool::Lexicon::Generation::CS;
use Treex::Tool::Depfix::CS::NumberSwitcher;

my ( $generator, $morphoLM, $numberSwitcher );

sub BUILD {
    my $self = shift;

    $generator = Treex::Tool::Lexicon::Generation::CS->new();
    $morphoLM  = LanguageModel::MorphoLM->new();
    $numberSwitcher = Treex::Tool::Depfix::CS::NumberSwitcher->new(
        generator => $self
    );

    return;
}

sub get_form {

    my ( $self, $lemma, $tag ) = @_;

    # TODO: use the proper way :-)
    $lemma =~ s/[-_].+$//;    # ???

    $tag =~ s/^V([ps])[IF]P/V$1TP/;
    $tag =~ s/^V([ps])[MI]S/V$1YS/;
    $tag =~ s/^V([ps])(FS|NP)/V$1QW/;

    $tag =~ s/^(P.)FS/$1\[FHQTX\-\]S/;
    $tag =~ s/^(P.)F([^S])/$1\[FHTX\-\]$2/;
    $tag =~ s/^(P.)NP/$1\[NHQXZ\-\]P/;
    $tag =~ s/^(P.)N([^P])/$1\[NHXZ\-\]$2/;

    $tag =~ s/^(P.)I/$1\[ITXYZ\-\]/;
    $tag =~ s/^(P.)M/$1\[MXYZ\-\]/;
    $tag =~ s/^(P.+)P(...........)/$1\[DPWX\-\]$2/;
    $tag =~ s/^(P.+)S(...........)/$1\[SWX\-\]$2/;

    $tag =~ s/^(P.+)(\d)(..........)/$1\[$2X\]$3/;

    my $form_info = $morphoLM->best_form_of_lemma( $lemma, $tag );
    my $form = undef;
    $form = $form_info->get_form() if $form_info;

    if ( !$form ) {
        ($form_info) = $generator->forms_of_lemma(
            $lemma, { tag_regex => "^$tag" }
        );
        $form = $form_info->get_form() if $form_info;
    }

    # the "1" variant can be safely ignored
    if ( !$form && $tag =~ /1$/ ) {
        $tag =~ s/1$/-/;
        return $self->get_form( $lemma, $tag );
    }

    # numerals have deterministic number
    if ( !$form && $tag =~ /^C/ ) {
        if ( $tag =~ /^(...)S(.+)$/ ) {
            $tag = $1 . 'P' . $2;
        } else {
            $tag = $1 . 'S' . $2;
        }
        return $self->get_form( $lemma, $tag );
    }

    # reasonable but does not bring any improvement:
    # if the tag is corrupt, it is usually a good idea not to try to
    # generate any form and to keep the current form unchanged
    #    if ( !$form && $lemma eq 'být' && $byt_forms{$tag} ) {
    #        return $byt_forms{$tag};
    #    }

    if ( !$form ) {
        log_info("Can't find a word for lemma '$lemma' and tag '$tag'.");
    }

    # the morphology has serious problems with this verb
    if ( $tag =~ /^V/ && $lemma =~ /^stát/ && $form !~ /^sta[ln]/ ) {
        return;
    }

    return $form;
}

# changes the tag in the node and regebnerates the form correspondingly
sub regenerate_node {
    my ( $self, $node, $dont_try_switch_number, $ennode ) = @_;

    my $old_form = $node->form;
    my $new_tag = $node->tag;

    if ( !$dont_try_switch_number ) {
        $new_tag =
            $numberSwitcher->try_switch_node_number( $node, $ennode );
        $node->set_tag($new_tag);
    }
    
    my $new_form = $self->get_form( $node->lemma, $new_tag );
    return if !defined $new_form;
    
    $new_form = ucfirst $new_form if $old_form =~ /^(\p{isUpper})/;
    $new_form = uc $new_form      if $old_form =~ /^(\p{isUpper}*)$/;
    $node->set_form($new_form);

    return $new_form;
}


# my %byt_forms = (
#
#     # correct forms
#     'VB-S---3P-AA---' => 'je',
#     'VB-S---3P-NA---' => 'není',
#     'VB-P---3P-AA---' => 'jsou',
#     'VB-P---3P-NA---' => 'nejsou',
#     'VB-S---3F-AA---' => 'bude',
#     'VB-S---3F-NA---' => 'nebude',
#     'VB-P---3F-AA---' => 'budou',
#     'VB-P---3F-NA---' => 'nebudou',
#     'VpYS---XR-AA---' => 'byl',
#     'VpYS---XR-NA---' => 'nebyl',
#     'VpQW---XR-AA---' => 'byla',
#     'VpQW---XR-NA---' => 'nebyla',
#     'VpNS---XR-AA---' => 'bylo',
#     'VpNS---XR-NA---' => 'nebylo',
#     'VpMP---XR-AA---' => 'byli',
#     'VpMP---XR-NA---' => 'nebyli',
#     'VpTP---XR-AA---' => 'byly',
#     'VpTP---XR-NA---' => 'nebyly',
#
#     # heuristics for incomplete or overcomplete tags
#     # present
#     'VB-----3P-AA---' => 'je',
#     'VB-----3P-NA---' => 'není',
#     'VB-X---3P-AA---' => 'je',
#     'VB-X---3P-NA---' => 'není',
#
#     # future
#     'VB-----3F-AA---' => 'bude',
#     'VB-----3F-NA---' => 'nebude',
#     'VB-X---3F-AA---' => 'bude',
#     'VB-X---3F-NA---' => 'nebude',
#
#     # past
#     'VpM----XR-AA---' => 'byl',
#     'VpM----XR-NA---' => 'nebyl',
#     'VpMX---XR-AA---' => 'byl',
#     'VpMX---XR-NA---' => 'nebyl',
#     'VpI----XR-AA---' => 'byl',
#     'VpI----XR-NA---' => 'nebyl',
#     'VpIX---XR-AA---' => 'byl',
#     'VpIX---XR-NA---' => 'nebyl',
#     'VpF----XR-AA---' => 'byla',
#     'VpF----XR-NA---' => 'nebyla',
#     'VpFX---XR-AA---' => 'byla',
#     'VpFX---XR-NA---' => 'nebyla',
#
# );

1;

=head1 NAME 

Treex::Tool::Depfix::CS::FormGenerator

=head1 DESCRIPTION

This package provides the L<get_form> method,
which tries to generate the wordform
corresponding to the given lemma and tag.

=head1 METHODS

=over

=item my $form = $formGenerator->get_form($lemma, $tag)

Returns the form corresponding to the given lemma and tag, 
or C<undef> if no form can be generated.
In such case, it also issues the following warning:
"Can't find a word for lemma '$lemma' and tag '$tag'."

=back

=head1 AUTHOR

David Marecek <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
