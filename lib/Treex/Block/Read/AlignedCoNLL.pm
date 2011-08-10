package Treex::Block::Read::AlignedCoNLL;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseAlignedTextReader';

sub next_document {
    my ($self) = @_;
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
                my ( $id, $form, $lemma, $plemma, $pos, $ppos, $feat, $pfeat, $head, $phead, $deprel, $pdeprel ) = split( /\t/, $token );
                my $newnode = $aroot->create_child();
                $newnode->shift_after_subtree($aroot);
                $lemma  = $plemma  if $lemma  eq '_';
                $pos    = $ppos    if $pos    eq '_';
                $head   = $phead   if $head   eq '_';
                $deprel = $pdeprel if $deprel eq '_';
                $newnode->set_form($form);
                $newnode->set_lemma($lemma);
                $newnode->set_tag($pos);
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

treex Read::AlignedCoNLL en=en1.conll,en2.conll cs=cs1.conll,cs2.conll

Copyright (c) 2011 David Marecek
