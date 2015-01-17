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
has 'deprel_attribute'                 => ( is       => 'rw', isa => 'Str', default => 'autodetect' );
has 'is_member_within_afun'            => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'is_shared_modifier_within_afun'   => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'is_coord_conjunction_within_afun' => ( is       => 'rw', isa => 'Bool', default => 0 );
has 'randomly_select_sentences_ratio'  => ( is       => 'rw', isa => 'Num',  default => 1 );

has _was => ( is => 'rw', default => sub{{}} );

has '+extension' => ( default => '.conllu' );
has 'last_file_stem' => ( is => 'rw', isa => 'Str', default => '' );
has 'sent_in_file'   => ( is => 'rw', isa => 'Int', default => 0 );

sub process_atree
{
    my $self = shift;
    my $tree = shift;
    # if only random sentences are printed
    return if(rand() > $self->randomly_select_sentences_ratio());
    # We require that the token ids make an unbroken sequence, starting at 1.
    # Unfortunately, this is not guaranteed in the general case.
    # So we have to re-index the nodes ourselves.
    $self->_normalize_node_ordering($tree);
    my @nodes = $tree->get_descendants({ordered => 1});
    # Empty sentences are not allowed.
    return if(scalar(@nodes)==0);
    
   # Print the original CoNLL-U comment if present
    my $comment = $tree->get_bundle->wild->{comment};
    if ($comment) {
        chomp $comment;
        $comment =~ s/\n/\n#/g;
        say {$self->_file_handle()} '#'.$comment;
    }

    
    # Print sentence ID as a comment before the sentence.
    # Example: "a-cmpr9406-001-p2s1" is the ID of the a-tree of the first training sentence of PDT, "Třikrát rychlejší než slovo".
    # The sentence comes from the file "cmpr9406_001.a.gz".
    # We could also figure out the file name stem this way:
    # my $file = $tree->get_zone()->get_document()->file_stem();
    # It would not make sense in all situations to output it as another comment. We will not always be reading the PDT.
    # However, it is very useful for debugging purposes to be able to find the original representation (including number of the sentence in the file).
    if ($self->print_id){
        print {$self->_file_handle()} ("\# sent_id ", $tree->id(), "\n");
        my $file_stem = $tree->get_zone()->get_document()->file_stem();
        if($file_stem eq $self->last_file_stem())
        {
            $self->set_sent_in_file($self->sent_in_file() + 1);
        }
        else
        {
            $self->set_last_file_stem($file_stem);
            $self->set_sent_in_file(1);
        }
        my $sent_in_file = $self->sent_in_file();
        print {$self->_file_handle()} ("\# orig_file_sentence $file_stem\#$sent_in_file\n");
    }
    foreach my $node (@nodes)
    {
        my $ord = $node->wild()->{outord};
        my $range = $ord =~ m/-/;
        my $form = $node->form();
        my $lemma = $range ? '_' : $node->lemma();
        my $tag = $range ? '_' : $node->tag();
        my $isetfs = $node->iset();
        my $upos_features = $range ? "_\t_" : encode('mul::uposf', $isetfs);
        my ($upos, $feat) = split(/\t/, $upos_features);
        my $pord = $range ? '_' : $node->get_parent()->wild()->{outord};
        my $misc = $node->no_space_after() ? 'SpaceAfter=No' : '_';
        # 'conll/' will be prefixed if needed; see get_attribute().
        my $deprel = $range ? '_' : $self->get_attribute($node, 'deprel');
        # Append suffices to afuns.
        ###!!! We will want to remove this in future. The dependency labels we output will have to conform to the Universal Dependencies standard.
        my $suffix = '';
        $suffix .= 'M' if $self->is_member_within_afun            && $node->is_member;
        $suffix .= 'S' if $self->is_shared_modifier_within_afun   && $node->is_shared_modifier;
        $suffix .= 'C' if $self->is_coord_conjunction_within_afun && $node->wild->{is_coord_conjunction};
        $deprel .= "_$suffix" if $suffix;
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



#------------------------------------------------------------------------------
# Looks for tokens split to multiple syntactic words and adjusts the ID (ord)
# value accordingly. At present this information is stored among the wild
# attributes.
#------------------------------------------------------------------------------
sub _normalize_node_ordering
{
    my $self = shift;
    my $tree = shift;
    # The ord attribute is useless if there are split fused tokens.
    # The 'decord' wild attribute may has decimal values for artificial nodes for token parts.
    # Make sure that all nodes have the 'decord' value.
    my @nodes = $tree->get_descendants();
    foreach my $node (@nodes)
    {
        if(!defined($node->wild()->{decord}))
        {
            $node->wild()->{decord} = $node->ord();
        }
    }
    @nodes = sort {$a->wild()->{decord} <=> $b->wild()->{decord}} (@nodes);
    # Make sure that
    # - the first node is indexed by the integer 1
    # - the step between any two adjacent integers is 1
    # - the step between any two adjacent decimal, or an integer followed by a decimal, is 0.1
    # - if a decimal is followed by an integer, it is the next available integer
    ###!!! We assume that any fused token is split to a maximum of 9 syntactic words, i.e. decimals 2.10 or 2.11 will never occur!
    $tree->wild()->{decord} = 0;
    $tree->wild()->{outord} = 0; # needed as parent ord
    my $last_int = 0;
    my $last_dec = 0.0;
    my $last_out = 0;
    my $last_int_node;
    foreach my $node (@nodes)
    {
        my $decord = $node->wild()->{decord};
        my $outord;
        if($decord =~ m/^(\d+)\.(\d+)$/)
        {
            if($last_int==0)
            {
                # This error is fatal. It is not clear what we should print out.
                log_fatal("Decimally indexed syntactic word without any preceding surface token");
            }
            if($last_dec =~ m/\.9$/)
            {
                log_fatal("We cannot currently process more than 9 syntactic words fused into one token");
            }
            $decord = $last_dec + 0.1;
            # If this is X.1, we should actually steal the outord from the previous (surface) token.
            if($decord =~ m/\.1$/)
            {
                $outord = $last_out;
                $last_int_node->wild()->{outord} = "$outord-$outord";
            }
            else
            {
                $outord = $last_out + 1;
                $last_int_node->wild()->{outord} =~ s/-\d+$/-$outord/;
            }
            # Update memory for the next loop.
            $last_dec = $decord;
            $last_out = $outord;
        }
        else # this is integer
        {
            $decord = $last_int + 1;
            $outord = $last_out + 1;
            # Update memory for the next loop.
            $last_int = $decord;
            $last_dec = $decord.'.0';
            $last_out = $outord;
            $last_int_node = $node;
        }
        $node->wild()->{decord} = $decord;
        $node->wild()->{outord} = $outord;
    }
}



#------------------------------------------------------------------------------
# Maps Treex attributes to CoNLL-U columns. The mapping is parameterizable in
# some cases.
#------------------------------------------------------------------------------
sub get_attribute
{
    my $self = shift;
    my $node = shift;
    my $name = shift;
    my $from = $self->{ $name . '_attribute' } || $name;    # TODO don't expect blessed hashref
    my $value;
    if ($from eq 'autodetect')
    {
        my $before = $self->_was->{$name};
        if (!defined($before))
        {
            $value = $node->get_attr("conll/$name");
            if (defined($value))
            {
                $self->_was->{$name} = "conll/$name";
            }
            else
            {
                my $fallback = $FALLBACK_FOR{$name} or log_fatal("No fallback for attribute $name");
                $value = $node->get_attr($fallback);
                $self->_was->{$name} = $fallback;
            }
        }
        else
        {
            $value = $node->get_attr($before);
            if (!defined($value) && $before =~ /^conll/)
            {
                my $id = $node->get_address();
                log_warn("Attribute $before not defined in $id but non-empty values did appear previously. Consider Write::CoNLLU with the parameter ${name}_attribute != autodetect.");
            }
        }
    }
    else
    {
        $value = $node->get_attr($from);
    }
    return defined($value) ? $value : '_';
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

=item deprel_attribute

The name of attribute which will be printed into the 8th column (dependency relation).
Default is C<autodetect> which tries first C<conll/deprel>
and if it is not defined then C<afun>.

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
