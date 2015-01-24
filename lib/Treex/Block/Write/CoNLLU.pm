package Treex::Block::Write::CoNLLU;

use strict;
use warnings;
use Moose;
use Lingua::Interset qw(encode);
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

my %FALLBACK_FOR = ( 'pos' => 'tag', 'deprel' => 'afun', );

has '+language'                        => ( required => 1 );
has 'print_id'                         => ( is       => 'ro', isa => 'Bool', default => 1, documentation => 'print sent_id and orig_file_sentence in CoNLL-U comment before each sentence' );
has 'randomly_select_sentences_ratio'  => ( is       => 'rw', isa => 'Num',  default => 1 );

has _was => ( is => 'rw', default => sub{{}} );

has '+extension' => ( default => '.conllu' );

sub process_atree
{
    my $self = shift;
    my $tree = shift;
    # if only random sentences are printed
    return if(rand() > $self->randomly_select_sentences_ratio());
    my @nodes = $tree->get_descendants({ordered => 1});
    # Empty sentences are not allowed.
    return if(scalar(@nodes)==0);
    # Print sentence ID as a comment before the sentence.
    # Example: "a-cmpr9406-001-p2s1" is the ID of the a-tree of the first training sentence of PDT, "Třikrát rychlejší než slovo".
    if ($self->print_id)
    {
        print {$self->_file_handle()} ("\# sent_id ", $tree->id(), "\n");
    }
    # Print the original CoNLL-U comments for this sentence if present.
    my $comment = $tree->get_bundle->wild->{comment};
    if ($comment)
    {
        chomp $comment;
        $comment =~ s/\n/\n# /g;
        say {$self->_file_handle()} '# '.$comment;
    }
    foreach my $node (@nodes)
    {
        my $fused = $node->wild()->{fused};
        if(defined($fused) && $fused eq 'start')
        {
            my $range = $node->wild()->{fused_start}->ord().'-'.$node->wild()->{fused_end}->ord();
            my $form = $node->wild()->{fused_form};
            print { $self->_file_handle() } ("$range\t$form\t_\t_\t_\t_\t_\t_\t_\t_\n");
        }
        my $ord = $node->ord();
        my $form = $node->form();
        my $lemma = $node->lemma();
        my $tag = $node->tag();
        my $isetfs = $node->iset();
        my $upos_features = encode('mul::uposf', $isetfs);
        my ($upos, $feat) = split(/\t/, $upos_features);
        my $pord = $node->get_parent()->ord();
        my $misc = $node->no_space_after() ? 'SpaceAfter=No' : '_';
        ###!!! In future we will probably dedicate a new attribute called simply 'deprel'.
        ###!!! Not 'afun' because it is a weird name and it is too closely bound to PDT.
        ###!!! And not 'conll/deprel' because the 'conll/*' attributes are something extra, and one could think they are optional.
        my $deprel = $node->conll_deprel();
        # CoNLL-U columns: ID, FORM, LEMMA, CPOSTAG=UPOS, POSTAG=corpus-specific, FEATS, HEAD, DEPREL, DEPS(additional), MISC
        # Make sure that values are not empty and that they do not contain spaces.
        my @values = ($ord, $form, $lemma, $upos, $tag, $feat, $pord, $deprel, '_', $misc);
        @values = map
        {
            my $x = $_ // '_';
            $x =~ s/^\s+//;
            $x =~ s/\s+$//;
            $x =~ s/\s+/_/g;
            $x = '_' if($x eq '');
            $x
        }
        (@values);
        ###!!! It is still not guaranteed that features output by Interset are sorted alphabetically.
        ###!!! Interset uses a sorting approach where uppercase letters come before lowercase:
        ###!!! Case=Gen|NumForm=Word|NumType=Card|NumValue=1,2,3|Number=Plur
        $values[5] = join('|', sort {lc($a) cmp lc($b)} (split(/\|/, $values[5])));
        print { $self->_file_handle() } join("\t", @values)."\n";
    }
    print { $self->_file_handle() } "\n" if($tree->get_descendants());
    return;
}

1;

__END__

=head1 NAME

Treex::Block::Write::CoNLLU

=head1 DESCRIPTION

Document writer for the CoNLL-U data format
(L<http://universaldependencies.github.io/docs/format.html>).

=head1 PARAMETERS

=over

=item encoding

Output encoding. C<utf8> by default.

=item to

The name of the output file, STDOUT by default.

=back

=head1 METHODS

=over

=item process_atree

Saves (prints) the CoNLL-U representation of one sentence (one dependency tree).

=back

=head1 AUTHOR

Daniel Zeman

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
