package Treex::Block::Read::CoNLLX;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
use File::Slurp;
extends 'Treex::Block::Read::BaseCoNLLReader';

has 'feat_is_iset'   => ( is => 'rw', isa => 'Bool', default => 0 );
has 'deprel_is_afun' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'is_member_within_afun' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'is_parenthesis_root_within_afun' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'sid_within_feat' => ( is => 'rw', isa => 'Bool', default => 0, documentation => 'A sid=.+ feature is interpreted as sentence (bundle) id. Read from first node, erased from all.' );

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();
    foreach my $tree ( split /\n\s*\n/, $text ) {
        my @tokens  = split( /\n/, $tree );
        # Skip empty sentences (if any sentence is empty at all,
        # typically it is the first or the last one because of superfluous empty lines).
        next unless(@tokens);
        my $bundle  = $document->create_bundle();
        # The default bundle id is something like "s1" where 1 is the number of the sentence.
        # If the input file is split to multiple Treex documents, it is the index of the sentence in the current output document.
        # But we want the input sentence number. If the Treex documents are later exported to one file again, the sentence ids should remain unique.
        my $sentid = $self->sent_in_file() + 1;
        my $sid = $self->sid_prefix().'s'.$sentid;
        $bundle->set_id($sid);
        $self->set_sent_in_file($sentid);
        my $zone    = $bundle->create_zone( $self->language, $self->selector );
        my $aroot   = $zone->create_atree();
        $aroot->set_id($sid.'/'.$self->language());
        if ( $self->deprel_is_afun ) {
            $aroot->set_afun('AuxS');
        }
        my @parents = (0);
        my @nodes   = ($aroot);
        my $sentence;
        my $sid_set = 0;
        foreach my $token (@tokens) {
            next if $token =~ /^\s*$/;
            my ( $id, $form, $lemma, $cpos, $pos, $feat, $head, $deprel ) = split( /\t/, $token );
            if ( $self->sid_within_feat() )
            {
                my @feat = split(/\|/, $feat);
                my @sid = grep {m/^sid=.+$/} (@feat);
                @feat = grep {!m/^sid=.+$/} (@feat);
                $feat = join('|', @feat);
                $feat = '_' if(!defined($feat) || $feat eq '');
                if ( !$sid_set && scalar(@sid) >= 1 )
                {
                    $sid[0] =~ m/^sid=(.+)$/;
                    $bundle->set_id($1);
                    $sid_set = 1;
                }
            }
            my $newnode = $aroot->create_child();
            $newnode->shift_after_subtree($aroot);
            $newnode->set_form($form);
            $newnode->set_lemma($lemma);
            $newnode->set_tag($pos);
            $newnode->set_conll_cpos($cpos);
            $newnode->set_conll_pos($pos);
            $newnode->set_conll_feat($feat);
            if ( $self->feat_is_iset ) {
                $newnode->set_iset_conll_feat($feat);
            }
            if($self->is_parenthesis_root_within_afun)
            {
                if($deprel =~ s/_P$// || $deprel =~ s/_MP$/_M/ || $deprel =~ s/_PM$/_M/)
                {
                    $newnode->set_is_parenthesis_root(1);
                }
            }
            if($self->is_member_within_afun() && $deprel =~ s/_M$//)
            {
                $newnode->set_is_member(1);
            }
            $newnode->set_conll_deprel($deprel);
            if ( $self->deprel_is_afun ) {
                if ( $deprel =~ /_M$/ ) {
                    $newnode->set_is_member(1);
                    $deprel =~ s/_M$//;
                }
                $newnode->set_afun($deprel);
            }
            $sentence .= "$form " if(defined($form));
            push @nodes,   $newnode;
            push @parents, $head;
        }
        foreach my $i ( 1 .. $#nodes ) {
            $nodes[$i]->set_parent( $nodes[ $parents[$i] ] );
        }
        $sentence =~ s/\s+$//;
        $zone->set_sentence($sentence);
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::CoNLLX

=head1 DESCRIPTION

Document reader for CoNLL format.
Each token is on separated line in the following format:
ord<tab>form<tab>lemma<tab>cpos<tab>pos<tab>features<tab>head<tab>deprel
Sentences are separated with blank line.
The sentences are stored into L<bundles|Treex::Core::Bundle> in the
L<document|Treex::Core::Document>.

See L<http://ilk.uvt.nl/conll/#dataformat>.

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=item lines_per_doc

number of sentences (!) per document

=item feat_is_iset

C<1> if the features field is a serialization of Interset
(e.g. C<pos=adj|prontype=dem|number=plu|case=dat|person=3>)
to read it directly into the Interset represenation for each node.
C<0> by default.

=item deprel_is_afun

C<1> if the deprel field is an afun (e.g. C<Sb>, C<Obj_M>, C<Pnom>)
to read it directly into the C<afun> field for each node
(also strips C<_M> and sets C<is_member> to C<1>).
C<0> by default.

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

David Mareček <marecek@ufal.mff.cuni.cz>
Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2013, 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
