package Treex::Block::Write::CoNLLU;
use Moose;
use Lingua::Interset qw(encode);
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has 'print_sent_id'                    => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'print sent_id in CoNLL-U comment before each sentence' );
has 'print_zone_id'                    => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'include zone id in sent_id comment after a slash' );
has 'print_text'                       => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'print sentence text in CoNLL-U comment before each sentence' );
has 'sort_misc'                        => ( is => 'ro', isa => 'Bool', default => 0, documentation => 'MISC attributes will be sorted alphabetically' );
has 'randomly_select_sentences_ratio'  => ( is => 'rw', isa => 'Num',  default => 1 );
has 'alignment'                        => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'print alignment links in the 9th column' );

# Where to find which CoNLL-U column?
# All the following parameters can have a special value "0",
# which means exclude this column (use "_" instead).
# Otherwise they specify a comma-separated sequnce of attributes (fallbacks)
# to try and use the first non-empty one.
# The default values are chosen so they cover several scenarios
# e.g. (deprel in $node->deprel or $node->conll_deprel or $node->afun).
# However, when using this block in a given scenario where we know where to find each attribute,
# it is recommended to override these defaults by explicitly specifying the parameters
# and using just one item in each sequence.
# "iset" is a special value which means to use Lingua::Interset::encode('mul::uposf', $node->iset)
# for extracting UPOS and/or FEATS.
has 'upos' => ( is => 'ro', default => 'iset', documentation => 'list of node attributes to check when printing the UPOS column' );
has 'xpos' => ( is => 'ro', default => 'conll/pos,conll/cpos,tag', documentation => 'list of node attributes to check when printing the XPOS column' );
has 'feats' => ( is => 'ro', default => 'iset,conll/feat', documentation => 'list of node attributes to check when printing the FEATS column' );
has 'deprel' => ( is => 'ro', default => 'deprel,conll/deprel,afun', documentation => 'list of node attributes to check when printing the DEPREL column' );

has _was => ( is => 'rw', default => sub{{}} );

has '+extension' => ( default => '.conllu' );

sub _get_upos {
    my ($self, $node) = @_;
    my @attrs = split /,/, $self->upos;
    foreach my $attr (@attrs) {
        return '_' if $attr eq '0';
        # If we ask for UPOS from Interset and the Interset features are empty, we want to (and should!) get the 'X' tag.
        # Not '_' and not a substitute from the next available attribute (conll/pos etc.) which is not even a valid universal POS tag.
        if ($attr eq 'iset') {
            return $node->iset()->get_upos();
        } else {
            my $value = $node->get_attr($attr);
            return $value if defined $value && $value ne '';
        }
    }
    return '_';
}

sub _get_xpos {
    my ($self, $node) = @_;
    my @attrs = split /,/, $self->xpos;
    foreach my $attr (@attrs) {
        return '_' if $attr eq '0';
        my $value = $node->get_attr($attr);
        return $value if defined $value && $value ne '';
    }
    return '_';
}

sub _get_feats {
    my ($self, $node) = @_;
    my @attrs = split /,/, $self->feats;
    foreach my $attr (@attrs) {
        return '_' if $attr eq '0';
        if ($attr eq 'iset') {
            my $isetfs = $node->iset();
            if ($isetfs->get_nonempty_features()) {
                my $upos_features = encode('mul::uposf', $isetfs);
                my ($upos, $feat) = split(/\t/, $upos_features);
                return $feat;
            }
        } else {
            my $value = $node->get_attr($attr);
            return $value if defined $value && $value ne '';
        }
    }
    return '_';
}

sub _get_deprel {
    my ($self, $node) = @_;
    my @attrs = split /,/, $self->deprel;
    foreach my $attr (@attrs) {
        return '_' if $attr eq '0';
        my $value = $node->get_attr($attr);
        return $value if defined $value && $value ne '';
    }
    return '_';
}


sub process_atree {
    my ($self, $tree) = @_;

    # if only random sentences are printed
    return if(rand() > $self->randomly_select_sentences_ratio());
    my @nodes = $tree->get_descendants({ordered => 1});
    # Empty sentences are not allowed.
    return if(scalar(@nodes)==0);
    # Print sentence (bundle) ID as a comment before the sentence.
    my $comment = $tree->get_bundle()->wild()->{comment};
    my @comment;
    if ($comment)
    {
        chomp($comment);
        @comment = split(/\n/, $comment);
    }
    if ($self->print_sent_id)
    {
        # If the CoNLL-U comments contain document id and/or paragraph id, print them before the sentence id.
        my @newdocpar = grep {m/^new(doc|par)/i} (@comment);
        if (scalar(@newdocpar)>0)
        {
            foreach my $c (@newdocpar)
            {
                print {$self->_file_handle} ("# $c\n");
            }
            @comment = grep {!m/^new(doc|par)/i} (@comment);
        }
        my $sent_id = $tree->get_bundle->id;
        if ($self->print_zone_id)
        {
            $sent_id .= '/' . $tree->get_zone->get_label;
        }
        print {$self->_file_handle} "# sent_id = $sent_id\n";
    }
    if ($self->print_text)
    {
        my $text = $tree->get_zone->sentence;
        print {$self->_file_handle} "# text = $text\n" if defined $text;
    }
    # Print the original CoNLL-U comments for this sentence if present.
    if (scalar(@comment) > 0)
    {
        foreach my $c (@comment)
        {
            print {$self->_file_handle} ("# $c\n");
        }
    }
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        my $wild = $node->wild();
        my $fused = $wild->{fused};
        if(defined($fused) && $fused eq 'start')
        {
            my $first_fused_node_ord = $node->ord();
            my $last_fused_node_ord = $wild->{fused_end};
            my $last_fused_node_no_space_after = 0;
            # We used to save the ord of the last element with every fused element but now it is no longer guaranteed.
            # Let's find out.
            if(!defined($last_fused_node_ord))
            {
                for(my $j = $i+1; $j<=$#nodes; $j++)
                {
                    $last_fused_node_ord = $nodes[$j]->ord();
                    $last_fused_node_no_space_after = $nodes[$j]->no_space_after();
                    last if(defined($nodes[$j]->wild()->{fused}) && $nodes[$j]->wild()->{fused} eq 'end');
                }
            }
            else
            {
                my $last_fused_node = $nodes[$last_fused_node_ord-1];
                log_fatal('Node ord mismatch') if($last_fused_node->ord() != $last_fused_node_ord);
                $last_fused_node_no_space_after = $last_fused_node->no_space_after();
            }
            my $range = '0-0';
            if(defined($first_fused_node_ord) && defined($last_fused_node_ord))
            {
                $range = "$first_fused_node_ord-$last_fused_node_ord";
            }
            else
            {
                log_warn("Cannot determine the span of a fused token");
            }
            my $form = $wild->{fused_form};
            my $misc = $last_fused_node_no_space_after ? 'SpaceAfter=No' : '_';
            print { $self->_file_handle() } ("$range\t$form\t_\t_\t_\t_\t_\t_\t_\t$misc\n");
        }
        my $ord = $node->ord;
        my $pord = $node->get_parent->ord;
        my $form = $node->form;
        my $lemma = $node->lemma;

        my $upos = $self->_get_upos($node);
        my $xpos = $self->_get_xpos($node);
        my $deprel = $self->_get_deprel($node);
        my $feats = $self->_get_feats($node);

        # If transliteration of the word form to Latin (or another) alphabet is available, put it in the MISC column.
        if(defined($node->translit()))
        {
            $node->set_misc_attr('Translit', $node->translit())
        }
        my @misc = $node->get_misc();

        # In the case of fused surface token, SpaceAfter=No may be specified for the surface token but NOT for the individual syntactic words.
        if($node->no_space_after() && !defined($wild->{fused}))
        {
            unshift(@misc, 'SpaceAfter=No');
        }
        if(defined($node->wild()->{lemma_translit}) && $node->wild()->{lemma_translit} !~ m/^_?$/)
        {
            push(@misc, 'LTranslit='.$node->wild()->{lemma_translit});
        }
        ###!!! (Czech)-specific wild attributes that have been cut off the lemma.
        ###!!! In the future we will want to make them normal attributes.
        ###!!! Note: the {lid} attribute is now also collected for other treebanks, e.g. AGDT and LDT.
        if(exists($wild->{lid}) && defined($wild->{lid}))
        {
            if(defined($lemma))
            {
                push(@misc, "LId=$lemma-$wild->{lid}");
            }
            else
            {
                log_warn("UNDEFINED LEMMA: $ord $form $wild->{lid}");
            }
        }
        if(exists($wild->{lgloss}) && defined($wild->{lgloss}) && ref($wild->{lgloss}) eq 'ARRAY' && scalar(@{$wild->{lgloss}}) > 0)
        {
            my $lgloss = join(',', @{$wild->{lgloss}});
            push(@misc, "LGloss=$lgloss");
        }
        if(exists($wild->{lderiv}) && defined($wild->{lderiv}))
        {
            push(@misc, "LDeriv=$wild->{lderiv}");
        }
        if(exists($wild->{lnumvalue}) && defined($wild->{lnumvalue}))
        {
            push(@misc, "LNumValue=$wild->{lnumvalue}");
        }
        if($self->sort_misc())
        {
            @misc = sort {lc($a) cmp lc($b)} (@misc);
        }
        my $misc = scalar(@misc)>0 ? join('|', @misc) : '_';

        my $relations = '_';
        if ($self->alignment) {
            my ($al_nodes, $al_types) = $node->get_aligned_nodes({directed=>1});
            if (@$al_nodes) {
                $relations = join '|', map {$self->_print_alignment($al_nodes->[$_], $al_types->[$_])} (0 .. @$al_nodes-1);
            }
        }

        # CoNLL-U columns: ID, FORM, LEMMA, UPOS, XPOS(treebank-specific), FEATS, HEAD, DEPREL, DEPS(additional), MISC
        # Make sure that values are not empty and that they do not contain spaces.
        # Exception: FORM and LEMMA can contain spaces in approved cases and in Vietnamese.
        my @values = ($ord,
        #$form, $lemma,
        '_', '_', $upos, $xpos, $feats, $pord, $deprel, $relations, $misc);
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
        $values[1] = $form;
        $values[2] = $lemma;
        print { $self->_file_handle() } join("\t", @values)."\n";
    }
    print { $self->_file_handle() } "\n" if $tree->get_descendants();
    return;
}

sub _print_alignment {
    my ($self, $node, $type) = @_;
    my $id = $node->get_bundle->id;
    $id .= '/' . $node->get_zone->get_label;
    $id .= '#' . $node->ord;
    my $t = $type =~ /int/  ? 'int' :
            $type =~ /gdfa/ ? 'gdfa':
            $type =~ /left/ ? 'left':
            $type =~ /right/? 'right':
            $type =~ /rule|supervised/ ? 'rule' : 'other';
    return "$id:align_$t";
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

=item print_sent_id

Print C<sent_id> in CoNLL-U comment before each sentence.

=item print_zone_id

Include zone id in the C<sent_id> comment after a slash. Example:
C<sent_id = s350/cs>.

=item print_text

Print sentence text in CoNLL-U comment before each sentence.

=back

=head1 METHODS

=over

=item process_atree

Saves (prints) the CoNLL-U representation of one sentence (one dependency tree).

=back

=head1 AUTHOR

Daniel Zeman

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2014, 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
