package Treex::Block::Read::CoNLLU;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
use File::Slurp;
use Try::Tiny;
extends 'Treex::Block::Read::BaseCoNLLReader';

my %UFEAT2INTERSET = (
    animacy => 'animateness',
    negative => 'negativeness',
    definite => 'definiteness',
    adptype => 'adpostype',
    'number[psor]' => 'possnumber',
    'gender[psor]' => 'possgender',
);

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();
    foreach my $tree ( split /\n\s*\n/, $text ) {
        my @lines  = split( /\n/, $tree );

        # Skip empty sentences (if any sentence is empty at all,
        # typically it is the first or the last one because of superfluous empty lines).
        next unless(@lines);
        my $comment = '';
        my $bundle  = $document->create_bundle();
        my $zone    = $bundle->create_zone( $self->language, $self->selector );
        my $aroot   = $zone->create_atree();
        my @parents = (0);
        my @nodes   = ($aroot);
        my $sentence;
        my $printed_up_to = 0;

        LINE:
        foreach my $line (@lines) {
            next LINE if $line =~ /^\s*$/;
            if ($line =~ s/^#\s*//) {
                if ($line =~ m/sent_id\s+(.*)/) {
                    $aroot->set_id( $1 );
                }
                else {
                    $comment .= "$line\n";
                }
                next LINE;
            }
            my ( $id, $form, $lemma, $cpostag, $postag, $feats, $head, $deprel, $deps, $misc, $rest ) = split( /\s/, $line );
            log_warn "Extra columns: '$rest'" if $rest;
            if ($id =~ /(\d+)-(\d+)/){
                $printed_up_to = $2;
                $sentence .= $form if defined $form;
                $sentence .= ' ' if $misc !~ /SpaceAfter=No/;
                next LINE;
            } elsif ($id > $printed_up_to){
                $sentence .= $form if defined $form;
                $sentence .= ' ' if $misc !~ /SpaceAfter=No/;
            }

            my $newnode = $aroot->create_child();
            $newnode->shift_after_subtree($aroot);
            $newnode->set_form($form);
            $newnode->set_lemma($lemma);
            $newnode->set_tag($postag);
            $newnode->set_conll_cpos($cpostag);
            $newnode->set_conll_pos($postag);
            $newnode->set_conll_feat($feats);
            $newnode->set_conll_deprel($deprel);

            $newnode->iset->set_upos($cpostag);
            if ($feats ne '_'){
                foreach my $feature (split /\|/, $feats){
                    # TODO: So far, Interset uses lowercase version of Universal Features
                    my ($name, $value) = map {lc} split /=/, $feature;
                    $name = $UFEAT2INTERSET{$name} || $name;
                    $value = $name if $value eq 'yes';
                    $value =~ s/,/|/g;

                    # TODO: support http://universaldependencies.github.io/docs/u/overview/feat-layers.html
                    try {
                        $newnode->iset->set($name, $value);
                    } catch {
                        log_warn "ignoring Interset error: $_";
                    }
                }
            }
            if ($misc && $misc =~ s/SpaceAfter=No//){
                $newnode->set_no_space_after(1);
            }
            if ($misc && $misc ne '_'){
                $newnode->wild->{misc} = $misc;
            }
            if ($deps && $deps ne '_'){
                $newnode->wild->{deps} = $deps;
            }

            push @nodes,   $newnode;
            push @parents, $head;
        }
        foreach my $i ( 1 .. $#nodes ) {
            $nodes[$i]->set_parent( $nodes[ $parents[$i] ] );
        }
        $sentence =~ s/\s+$//;
        $zone->set_sentence($sentence);
        $bundle->wild->{comment} = $comment;
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::CoNLLU - read CoNLL-U format.

=head1 DESCRIPTION

Document reader for CoNLL-U format for Universal Dependencies
(L<http://universaldependencies.github.io/docs/format.html>).

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=item lines_per_doc

number of sentences (!) per document

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 SEE

L<Treex::Block::Read::BaseTextReader>
L<Treex::Core::Document>
L<Treex::Core::Bundle>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
