package Treex::Block::Write::SemEval2010;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

Readonly my $NOT_SET   => "_";    # CoNLL-ST format: undefined value

has '+language' => ( required => 1 );

has '+extension' => ( default => '.conll' );

override 'print_header' => sub {
    my ($self, $doc) = @_;
    print {$self->_file_handle} "#begin document " . $doc->full_filename . "\n";
};
override 'print_footer' => sub {
    my ($self, $doc) = @_;
    print {$self->_file_handle} "#end document " . $doc->full_filename . "\n";
};

sub process_atree {
    my ($self, $atree) = @_;
    my @nodes = $atree->get_descendants({ordered => 1});

    my @data = map {_extract_data($_)} @nodes;
   
    my $str = join "\n", (map {join "\t", @$_} @data);
    print { $self->_file_handle } "$str\n\n";
}

sub _create_coref_str {
    my ($anode) = @_;

    my @start = defined $anode->wild->{coref_mention_start} ? sort {$a <=> $b} @{$anode->wild->{coref_mention_start}} : ();
    my @end = defined $anode->wild->{coref_mention_end} ? sort {$a <=> $b} @{$anode->wild->{coref_mention_end}} : ();
    
    my @strs = ();

    my $s_eid = shift @start;
    my $e_eid = shift @end;
    while (defined $s_eid && defined $e_eid) {
        if ($s_eid == $e_eid) {
            push @strs, "(". $s_eid .")";
            $s_eid = shift @start;
            $e_eid = shift @end;
        }
        elsif ($s_eid < $e_eid) {
            push @strs, "(" . $s_eid;
            $s_eid = shift @start;
        }
        elsif ($s_eid > $e_eid) {
            push @strs, $e_eid . ")";
            $e_eid = shift @end;
        }
    }
    while (defined $s_eid) {
        push @strs, "(" . $s_eid;
        $s_eid = shift @start;
    }
    while (defined $e_eid) {
        push @strs, $e_eid . ")";
        $e_eid = shift @end;
    }

    my $str = join "|", @strs;
    return $str;
}

sub _extract_data {
    my ($anode) = @_;

    my $parent_ord = !$anode->is_root ? $anode->get_parent->ord : 0;
    my $coref = _create_coref_str($anode) || $NOT_SET;

    my @cols = (
        $anode->ord,        # Col 1     ID: word identifiers in the sentence
        $anode->form,       # Col 2     TOKEN: word forms
        $anode->lemma,      # Col 3     LEMMA: word lemmas (gold standard manual annotation)
        $NOT_SET,           # Col 4     PLEMMA: word lemmas predicted by an automatic analyzer
        $anode->tag,        # Col 5     POS: coarse part of speech
        $NOT_SET,           # Col 6     PPOS same as 5 but predicted by an automatic analyzer
        $NOT_SET,           # Col 7     FEAT: morphological features (part of speech type, number, gender, case, tense, aspect, degree of comparison, etc., separated by the character "|")
        $NOT_SET,           # Col 8     PFEAT: same as 7 but predicted by an automatic analyzer
        $parent_ord,        # Col 9     HEAD: for each word, the ID of the syntactic head ('0' if the word is the root of the tree)
        $NOT_SET,           # Col 10    PHEAD: same as 9 but predicted by an automatic analyzer 
        $anode->afun,       # Col 11    DEPREL: dependency relation labels corresponding to the dependencies  described in 9
        $NOT_SET,           # Col 12    PDEPREL: same as 11 but predicted by an automatic analyzer
        $NOT_SET,           # Col 13    NE: named entities
        $NOT_SET,           # Col 14    PNE: same as 13 but predicted by a named entity recognizer
        $NOT_SET,           # Col 15    PRED: predicates are marked and annotated with a semantic class label 
        $NOT_SET,           # Col 16    PPRED: Same as 13 but predicted by an automatic analyzer
                            # Col *     APREDs: N columns, one for each predicate in 15, containing the semantic roles/dependencies of each particular predicate
                            # Col *     PAPREDs: M columns, one for each predicate in 16, with the same information as APREDs but predicted with an automatic analyzer
        $coref,             # Col -1    COREF: coreference annotation in open-close notation, using "|" to separate multiple annotations
    );
    return \@cols;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::SemEval2010

=head1 DESCRIPTION


=head1 PARAMETERS

=over

=item C<language>

This parameter is required.

=item C<to>

Optional: the name of the output file, STDOUT by default.

=item C<encoding>

Optional: the output encoding, C<utf8> by default.

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
