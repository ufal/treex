package Treex::Block::Write::CoNLLU;
use Moose;
use Unicode::Normalize;
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
has 'upos' => ( is => 'ro', default => 'tag,iset', documentation => 'list of node attributes to check when printing the UPOS column' );
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


sub process_atree
{
    my ($self, $tree) = @_;

    # if only random sentences are printed
    return if(rand() > $self->randomly_select_sentences_ratio());
    my @nodes = $tree->get_descendants({ordered => 1});
    # Empty sentences are not allowed.
    return if(scalar(@nodes)==0);
    # Print sentence (bundle) ID as a comment before the sentence.
    my $bwild = $tree->get_bundle()->wild();
    my $comment = $bwild->{comment};
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
                $self->print_nfc("# $c\n");
            }
            @comment = grep {!m/^new(doc|par)/i} (@comment);
        }
        my $sent_id = $tree->get_bundle->id;
        if ($self->print_zone_id)
        {
            $sent_id .= '/' . $tree->get_zone->get_label;
        }
        $self->print_nfc("# sent_id = $sent_id\n");
    }
    if ($self->print_text)
    {
        my $text = $tree->get_zone->sentence;
        $self->print_nfc("# text = $text\n") if defined $text;
    }
    # Print the original CoNLL-U comments for this sentence if present.
    if (scalar(@comment) > 0)
    {
        foreach my $c (@comment)
        {
            if($c ne '')
            {
                $self->print_nfc("# $c\n");
            }
            else
            {
                $self->print_nfc("#\n");
            }
        }
    }
    # Before writing any nodes, search the wild attributes for enhanced dependencies.
    my %edeps_to_write;
    foreach my $node (@nodes)
    {
        my $is_empty = $node->deprel() eq 'dep:empty';
        if(exists($node->wild()->{enhanced}))
        {
            my @edeps = @{$node->wild()->{enhanced}};
            foreach my $edep (@edeps)
            {
                my $epord = $edep->[0];
                my $edeprel = $edep->[1];
                if($is_empty)
                {
                    my $enord = $node->wild()->{enord};
                    if(!defined($enord))
                    {
                        log_fatal("Unknown ID of an empty node.");
                    }
                    if($enord =~ m/^(\d+)\.(\d+)$/)
                    {
                        my $major = $1;
                        my $minor = $2;
                        $edeps_to_write{$enord}{$major}{$minor}{$epord}{$edeprel}++;
                    }
                    else
                    {
                        log_fatal("Unrecognized empty node ID '$enord'.");
                    }
                }
                else
                {
                    $edeps_to_write{$node->ord()}{0}{$epord}{$edeprel}++;
                }
            }
        }
    }
    # In addition, attributes of empty nodes, including leaf empty nodes, may
    # be stored in a wild attribute of the bundle.
    my %enodes_to_write;
    if(exists($bwild->{empty_nodes}))
    {
        my @empty_nodes = @{$bwild->{empty_nodes}};
        foreach my $empty_node (@empty_nodes)
        {
            if($empty_node->{id} =~ m/^(\d+)\.(\d+)$/)
            {
                $enodes_to_write{$1}{$2} = $empty_node;
            }
            else
            {
                log_warn("Cannot parse empty node id '$empty_node->{id}'");
            }
        }
    }

    # If there are any empty nodes positioned before the first real node,
    # write them now.
    $self->print_empty_nodes(\%enodes_to_write, \%edeps_to_write, 0);

    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        # We store UD empty nodes at the end of the sentence and in the basic tree,
        # we attach them to the artificial root via a fake dependency 'dep:empty'.
        last if($node->deprel() eq 'dep:empty');
        if($node->fused_with_next() && ($i==0 || !$nodes[$i-1]->fused_with_next()))
        {
            my $last_fused_node = $node->get_fusion_end();
            my $first_fused_node_ord = $node->ord();
            my $last_fused_node_ord = $last_fused_node->ord();
            my $last_fused_node_no_space_after = $last_fused_node->no_space_after();
            my $range = '0-0';
            if(defined($first_fused_node_ord) && defined($last_fused_node_ord))
            {
                $range = "$first_fused_node_ord-$last_fused_node_ord";
            }
            else
            {
                log_warn("Cannot determine the span of a fused token");
            }
            my $form = $node->get_fusion();
            my $misc = $node->get_fused_misc() // '';
            if($last_fused_node_no_space_after)
            {
                $misc = join('|', (split(/\|/, $misc), 'SpaceAfter=No'));
            }
            $misc = '_' if($misc eq '');
            $self->print_nfc("$range\t$form\t_\t_\t_\t_\t_\t_\t_\t$misc\n");
        }
        my $ord = $node->ord;
        my $pord = $node->get_parent->ord;
        my $form = $node->form;
        my $lemma = $node->lemma;

        my $upos = $self->_get_upos($node);
        my $xpos = $self->_get_xpos($node);
        my $deprel = $self->_get_deprel($node);
        my $feats = $self->_get_feats($node);

        # Enhanced dependencies have been prepared in a temporary hash.
        my $deps = '_';
        if(exists($edeps_to_write{$node->ord()}{0}))
        {
            my @edeps;
            foreach my $epord (sort {$a <=> $b} (keys(%{$edeps_to_write{$node->ord()}{0}})))
            {
                foreach my $edeprel (sort {$a cmp $b} (keys(%{$edeps_to_write{$node->ord()}{0}{$epord}})))
                {
                    push(@edeps, "$epord:$edeprel");
                }
            }
            if(scalar(@edeps) > 0)
            {
                $deps = join('|', @edeps);
            }
        }

        # If transliteration of the word form to Latin (or another) alphabet is available, put it in the MISC column.
        if(defined($node->translit()))
        {
            $node->set_misc_attr('Translit', $node->translit());
        }
        if(defined($node->ltranslit()))
        {
            $node->set_misc_attr('LTranslit', $node->ltranslit());
        }
        if(defined($node->gloss()))
        {
            $node->set_misc_attr('Gloss', $node->gloss());
        }
        my @misc = $node->get_misc();

        # In the case of fused surface token, SpaceAfter=No may be specified for the surface token but NOT for the individual syntactic words.
        if($node->no_space_after() && !$node->is_fused())
        {
            unshift(@misc, 'SpaceAfter=No');
        }
        if($self->sort_misc())
        {
            @misc = sort {lc($a) cmp lc($b)} (@misc);
        }
        # No MISC element should contain a vertical bar because we are going to
        # join them using the vertical bar as a separator. We will issue a
        # a warning if there is a vertical bar but we will not try to fix it
        # because the CoNLL-U format does not define any escaping method.
        foreach my $m (@misc)
        {
            if($m =~ m/\|/)
            {
                log_warn("MISC element '$m' should not contain the vertical bar '|'");
            }
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
        '_', '_', $upos, $xpos, $feats, $pord, $deprel, $deps, $misc);
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
        $values[1] = defined($form) && $form ne '' ? $form : '_';
        $values[2] = defined($lemma) && $lemma ne '' ? $lemma : '_';
        $self->print_nfc(join("\t", @values)."\n");

        # If there are any empty nodes positioned after the current real node,
        # write them now.
        $self->print_empty_nodes(\%enodes_to_write, \%edeps_to_write, $node->ord());
    }
    $self->print_nfc("\n") if $tree->get_descendants();
    return;
}



#------------------------------------------------------------------------------
# Prints all empty nodes after a given position.
#------------------------------------------------------------------------------
sub print_empty_nodes
{
    my $self = shift;
    my $enodestw = shift;
    my $edepstw = shift;
    my $major = shift;
    my %enodes_to_write = %{$enodestw};
    my %edeps_to_write = %{$edepstw};
    my %minors = ();
    if(exists($enodes_to_write{$major}))
    {
        foreach my $key (keys(%{$enodes_to_write{$major}}))
        {
            $minors{$key}++;
        }
    }
    if(exists($edeps_to_write{$major}))
    {
        foreach my $key (keys(%{$edeps_to_write{$major}}))
        {
            $minors{$key}++;
        }
    }
    my @minors = grep {$_ != 0} (sort {$a <=> $b} (keys(%minors)));
    foreach my $minor (@minors)
    {
        my $form = '_';
        my $lemma = '_';
        my $upos = '_';
        my $xpos = '_';
        my $feats = '_';
        my $deps = '_';
        my $misc = '_';
        if(exists($enodes_to_write{$major}{$minor}))
        {
            my $en = $enodes_to_write{$major}{$minor};
            ($form, $lemma, $upos, $xpos, $feats, $deps, $misc) = ($en->{form}, $en->{lemma}, $en->{upos}, $en->{xpos}, $en->{feats}, $en->{deps}, $en->{misc});
        }
        if(exists($edeps_to_write{$major}{$minor}))
        {
            my @edeps;
            foreach my $epord (sort {$a <=> $b} (keys(%{$edeps_to_write{$major}{$minor}})))
            {
                foreach my $edeprel (sort {$a cmp $b} (keys(%{$edeps_to_write{$major}{$minor}{$epord}})))
                {
                    push(@edeps, "$epord:$edeprel");
                }
            }
            if(scalar(@edeps) > 0)
            {
                $deps = join('|', @edeps);
            }
        }
        $self->print_nfc("$major.$minor\t$form\t$lemma\t$upos\t$xpos\t$feats\t_\t_\t$deps\t$misc\n");
    }
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



#------------------------------------------------------------------------------
# Normalizes Unicode to NFC and prints the result to the output file handle.
# Note that it is still possible to output unnormalized text if this method is
# called several times and problematic combining characters appear next to the
# border between two calls.
#------------------------------------------------------------------------------
sub print_nfc
{
    my $self = shift;
    my $string = shift;
    print {$self->_file_handle} (NFC($string));
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

Copyright © 2014, 2017, 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
