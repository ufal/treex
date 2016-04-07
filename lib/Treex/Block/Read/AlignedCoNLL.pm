package Treex::Block::Read::AlignedCoNLL;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseAlignedTextReader';



has 'conll_format' => ( is => 'ro', isa => 'Str', default => '2009', documentation => 'CoNLL flavor: 2006 or 2009, default is 2009.' );
has 'is_member_within_afun' => ( is => 'rw', isa => 'Bool', default => 0 );



sub next_document {
    my ($self) = @_;
    my $format = $self->conll_format();
    log_fatal("Unknown format flavor '$format'") unless($format =~ m/^200[69]$/);
    my $texts_ref = $self->next_document_texts();
    return if !defined $texts_ref;

    my %sentences =
        map { $_ => [ split /\n\n/, $texts_ref->{$_} ] } keys %{$texts_ref};

    my $n = 0;
    for my $zone_label ( keys %sentences ) {
        if ( !$n ) {
            $n = @{ $sentences{$zone_label} };
        }
        log_fatal "Different number of sentences in aligned documents"
            if $n != @{ $sentences{$zone_label} };
    }

    my $doc = $self->new_document();
    for my $i ( 0 .. $n - 1 ) {
        my $bundle = $doc->create_bundle();
        for my $zone_label ( keys %sentences ) {
            my ( $lang, $selector ) = ( $zone_label, $self->selector );
            if ( $zone_label =~ /_/ ) {
                ( $lang, $selector ) = split /_/, $zone_label;
            }
            my $zone = $bundle->create_zone( $lang, $selector );
            my @tokens  = split( /\n/, $sentences{$zone_label}[$i] );
            my $aroot   = $zone->create_atree();
            my @parents = (0);
            my @nodes   = ($aroot);
            my $sentence;
            foreach my $token (@tokens) {
                my ( $id, $form, $lemma, $plemma, $cpos, $pos, $ppos, $feat, $pfeat, $head, $phead, $deprel, $pdeprel );
                my @fields = split(/\t/, $token);
                if($format eq '2006')
                {
                    ($id, $form, $lemma, $cpos, $pos, $feat, $head, $deprel, $phead, $pdeprel) = @fields;
                }
                else
                {
                    ($id, $form, $lemma, $plemma, $pos, $ppos, $feat, $pfeat, $head, $phead, $deprel, $pdeprel) = @fields;
                }
                my $newnode = $aroot->create_child();
                $newnode->shift_after_subtree($aroot);
                $lemma  = $plemma  if $lemma  eq '_';
                $pos    = $ppos    if $pos    eq '_';
                $head   = $phead   if $head   eq '_';
                $deprel = $pdeprel if $deprel eq '_';
                if($self->is_member_within_afun() && $deprel =~ s/_M$//)
                {
                    $newnode->set_is_member(1);
                }
                $newnode->set_form($form);
                $newnode->set_lemma($lemma);
                $newnode->set_tag($pos);
                $newnode->set_deprel($deprel);
                $newnode->set_conll_cpos($cpos);
                $newnode->set_conll_pos($pos);
                $newnode->set_conll_feat($feat);
                $newnode->set_conll_deprel($deprel);
                $sentence .= "$form ";
                push @nodes,   $newnode;
                push @parents, $head;
            }
            foreach my $i ( 1 .. $#nodes ) {
                $nodes[$i]->set_parent( $nodes[ $parents[$i] ] );
            }
            $sentence =~ s/\s+$//;
            $zone->set_sentence($sentence);
        }
    }

    return $doc;
}

1;

__END__



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Block::Read::AlignedCoNLL

=head1 SYNOPSIS

  treex Read::AlignedCoNLL en=en1.conll,en2.conll cs=cs1.conll,cs2.conll
  treex Read::AlignedCoNLL sk_annotator1='!sk1*.conll' sk_annotator2='!sk2*.conll'

=head1 DESCRIPTION

Reads simultaneously from two parallel lists of CoNLL files. There should be the
same number of trees on both sides. Corresponding trees are loaded in different
zones of one bundle.

Names of parameters of this block specify the destination zone (language code
is optionally followed by underscore and selector). The parameter value is the
list of files for this zone.

This reader assumes the CoNLL 2009 file format.

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>,
Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
