package Treex::Block::T2T::TrLApplyTbxDictionary;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Block::Read::Treex;
use Treex::Block::T2T::TbxParser;
extends 'Treex::Core::Block';


has tbx => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'The path to the dictionary in tbx format.',
);

has tbx_src_id => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'The id of the source language in the dictionary.',
);

has tbx_trg_id => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'The id of the target language in the dictionary.',
);

has analysis => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'The path to the analyzed dictionary in streex format.',
);

has analysis_src_language => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'The id of the source language in the analysis.',
);

has analysis_src_selector => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'The source language selector in the analysis.',
);

has analysis_trg_language => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'The id of the target language in the analysis.',
);

has analysis_trg_selector => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'The target language selector in the analysis.',
);

has src_blacklist => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'A file with a list of the source entries to ignore, one entry per line.',
);

has trg_blacklist => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'A file with a list of the target entries to ignore, one entry per line.',
);

has pos_mismatch => ( # TODO Check that this parameter gets a valid value
    isa           => 'Str',
    is            => 'ro',
    documentation => "What to do if the PoS tag from the dictionary and the analysis do not match: 'ignore' to take the one from the analysis, 'fix' to take the one from the dictionary, or 'remove' to skip the entry. Defaults to 'remove'.",
    default       => 'remove',
);


my $UNDEF_SEMPOS = '__UNDEF_SEMPOS__';
my @CHILDREN_ATTRIBUTES = (qw(t_lemma formeme nodetype gram/sempos gram/gender gram/number gram/degcmp gram/verbmod gram/deontmod gram/tense gram/aspect gram/resultative gram/dispmod gram/iterativeness gram/indeftype gram/person gram/numertype gram/politeness gram/negation gram/definiteness gram/diathesis));


my %dictionary;
my @documents;


sub BUILD {
    my $self = shift;

    # Parse the tbx dictionary file
    my @tbx = Treex::Block::T2T::TbxParser->parse_tbx($self->tbx, $self->tbx_src_id, $self->tbx_trg_id);

    # Parse the blacklist files
    my %src_blacklist;
    if (defined $self->src_blacklist) {
        open(my $fh, '<:encoding(UTF-8)', Treex::Core::Resource::require_file_from_share($self->src_blacklist)) or die "Could not open file '" . $self->src_blacklist . "' $!";
        while (my $line = <$fh>) {
            $line =~ s/\R//g; # Remove newlines
            $src_blacklist{lc $line} = ();
        }
    }
    my %trg_blacklist;
    if (defined $self->trg_blacklist) {
        open(my $fh, '<:encoding(UTF-8)', Treex::Core::Resource::require_file_from_share($self->trg_blacklist)) or die "Could not open file '" . $self->trg_blacklist . "' $!";
        while (my $line = <$fh>) {
            $line =~ s/\R//g; # Remove newlines
            $trg_blacklist{lc $line} = ();
        }
    }

    my $multidocument = $self->analysis =~ /^@/;
    my $filename = $self->analysis;
    $filename =~ s/^@//g;
    $filename = Treex::Core::Resource::require_file_from_share($filename);
    my $treex_reader = Treex::Block::Read::Treex->new(from => $multidocument ? ('@' . $filename) : $filename);
    my $i = 0;
    while (my $document = $treex_reader->next_document()) {
        push @documents, $document;
        foreach my $bundle ($document->get_bundles()) {
            my $tbx_entry = $tbx[$i++];
            my $src_zone = $bundle->get_zone($self->analysis_src_language, $self->analysis_src_selector);
            my $trg_zone = $bundle->get_zone($self->analysis_trg_language, $self->analysis_trg_selector);
            my $src_ttree = $src_zone->get_ttree();
            my $trg_ttree = $trg_zone->get_ttree();
            my $src_root = $src_ttree->get_children({first_only=>1});
            my $trg_root = $trg_ttree->get_children({first_only=>1});

            # Remove generated nodes
            foreach my $tnode ($src_root->get_descendants()) {
                if ($tnode->is_generated) {
                    $tnode->remove();
                }
            }
            foreach my $tnode ($trg_root->get_descendants()) {
                if ($tnode->is_generated) {
                    $tnode->remove();
                }
            }

            my $src_size = $src_root->get_descendants({add_self=>1});
            my ($src_lemma, $src_sempos) = $src_root->get_attrs(qw(t_lemma gram/sempos));
            if (defined $src_sempos) {
                $src_sempos =~ "([^.]+).*";
                $src_sempos = $1;
            } else {
                $src_sempos = $UNDEF_SEMPOS;
            }
            my @src_preceding_children = $src_root->get_children({preceding_only=>1});
            my @src_following_children = $src_root->get_children({following_only=>1});
            my ($trg_lemma, $trg_sempos) = $trg_root->get_attrs(qw(t_lemma gram/sempos));
            if (defined $trg_sempos) {
                $trg_sempos =~ "([^.]+).*";
                $trg_sempos = $1;
            } else {
                $trg_sempos = $UNDEF_SEMPOS;
            }
            my @trg_preceding_children = $trg_root->get_children({preceding_only=>1});
            my @trg_following_children = $trg_root->get_children({following_only=>1});

            # Check that the entry is not in blacklisted
            if ((exists $src_blacklist{lc $tbx_entry->{SRC_TEXT}}) || (exists $trg_blacklist{lc $tbx_entry->{TRG_TEXT}})) {
                log_info("SKIPPING BLACKLISTED ENTRY:     " . $tbx_entry->{SRC_TEXT} . " (" . $tbx_entry->{SRC_SEMPOS} . ")  |  " . $tbx_entry->{TRG_TEXT} . " (" . $tbx_entry->{TRG_SEMPOS} . ")");
                next;
            }

            # Check the that the part-of-speech from the tbx dictionary and the analysis match
            if ($self->pos_mismatch eq 'fix') {
                $src_sempos = $tbx_entry->{SRC_SEMPOS};
                $trg_sempos = $tbx_entry->{TRG_SEMPOS};
            } elsif ($self->pos_mismatch eq 'remove' && ($src_sempos ne $tbx_entry->{SRC_SEMPOS} || $trg_sempos ne $tbx_entry->{TRG_SEMPOS})) {
                log_warn("SKIPPING ENTRY DUE TO POS MISMATCH:     " . $tbx_entry->{SRC_TEXT} . " (" . $tbx_entry->{SRC_SEMPOS} . " vs " . $src_sempos . ")  |  " . $tbx_entry->{TRG_TEXT} . " (" . $tbx_entry->{TRG_SEMPOS} . " vs " . $trg_sempos . ")");
                next;
            }

            # Add the entry into the dictionary
            my $key = "$src_lemma|$src_sempos";
            my $entry = {
                SRC_SIZE                =>  $src_size,
                SRC_TEXT                =>  $tbx_entry->{SRC_TEXT},
                SRC_LEMMA               =>  $src_lemma,
                SRC_SEMPOS              =>  $src_sempos,
                SRC_PRECEDING_CHILDREN  =>  \@src_preceding_children,
                SRC_FOLLOWING_CHILDREN  =>  \@src_following_children,
                TRG_TEXT                =>  $tbx_entry->{TRG_TEXT},
                TRG_LEMMA               =>  $trg_lemma,
                TRG_SEMPOS              =>  $trg_sempos,
                TRG_PRECEDING_CHILDREN  =>  \@trg_preceding_children,
                TRG_FOLLOWING_CHILDREN  =>  \@trg_following_children
            };
            if (exists $dictionary{$key}) {
                push @{$dictionary{$key}}, $entry
            } else {
                $dictionary{$key}[0] = $entry
            }
        }
    }

    # Sort the dictionary entries by length
    while (my $key = each %dictionary) {
        @{$dictionary{$key}} = sort {$b->{SRC_SIZE} <=> $a->{SRC_SIZE}} @{$dictionary{$key}};
    }
}


sub process_ttree {
    my ($self, $root) = @_;
    foreach my $tnode ($root->get_children({ordered => 1})) {
        $self->process_tnode($tnode);
    }
    return;
}


sub process_tnode {
    my ($self, $trg_tnode) = @_;

    # Skip nodes that were already translated by other rules
    return if $trg_tnode->t_lemma_origin !~ /^(clone|lookup)/;

    my $src_tnode = $trg_tnode->src_tnode or return;
    my ($src_tlemma, $src_sempos) = $src_tnode->get_attrs(qw(t_lemma gram/sempos));
    if (defined $src_tlemma) {
        if (defined $src_sempos) {
            $src_sempos =~ "([^.]+).*";
            $src_sempos = $1;
        } else {
            $src_sempos = $UNDEF_SEMPOS;
        }
        my $key = "$src_tlemma|$src_sempos";
        if (exists $dictionary{$key}) {
            my @matched_entries;
            my $matched_size = 0;
            my @preceding_children = $src_tnode->get_children({preceding_only=>1});
            my $preceding_children_size = scalar @preceding_children;
            my @following_children = $src_tnode->get_children({following_only=>1});
            my $following_children_size = scalar @following_children;
            foreach my $entry (@{$dictionary{$key}}) {
                my $size = $entry->{SRC_SIZE};
                if ($matched_size && $size < $matched_size) {
                    last;
                }
                my $entry_preceding_children = $entry->{SRC_PRECEDING_CHILDREN};
                my $entry_preceding_children_size = scalar @$entry_preceding_children;
                my $entry_following_children = $entry->{SRC_FOLLOWING_CHILDREN};
                my $entry_following_children_size = scalar @$entry_following_children;
                my $match = 1;
                if ($preceding_children_size < $entry_preceding_children_size || $following_children_size < $entry_following_children_size) {
                    $match = 0;
                } else {
                    my $from = $preceding_children_size - $entry_preceding_children_size;
                    my $to = $preceding_children_size - 1;
                    my @preceding_children_candidates = @preceding_children[$from..$to];
                    my $preceding_children_match = $self->match(\@preceding_children_candidates, $entry_preceding_children);
                    $from = 0;
                    $to = $entry_following_children_size - 1;
                    my @following_children_candidates = @following_children[$from..$to];
                    my $following_children_match = $self->match(\@following_children_candidates, $entry_following_children);
                    $match = $preceding_children_match && $following_children_match;
                }
                if ($match) {
                    $matched_size = $size;
                    push @matched_entries, $entry;
                }
            }

            my @unique_entries;
            my @repetitions;
            foreach my $entry (@matched_entries) {
                my $found = 0;
                for my $i (0..$#unique_entries) {
                    my $uentry = $unique_entries[$i];
                    my $match = ($entry->{SRC_LEMMA} eq $uentry->{SRC_LEMMA}) &&
                                ($entry->{TRG_LEMMA} eq $uentry->{TRG_LEMMA}) &&
                                ($entry->{SRC_SEMPOS} eq $uentry->{SRC_SEMPOS}) &&
                                $self->match($entry->{SRC_PRECEDING_CHILDREN}, $uentry->{SRC_PRECEDING_CHILDREN}) &&
                                $self->match($entry->{SRC_FOLLOWING_CHILDREN}, $uentry->{SRC_FOLLOWING_CHILDREN}) &&
                                $self->match($entry->{TRG_PRECEDING_CHILDREN}, $uentry->{TRG_PRECEDING_CHILDREN}) &&
                                $self->match($entry->{TRG_FOLLOWING_CHILDREN}, $uentry->{TRG_FOLLOWING_CHILDREN});
                    if ($match) {
                        $repetitions[$i]++;
                        $found = 1;
                    }
                }
                if (!$found) {
                    push @unique_entries, $entry;
                    push @repetitions, 1;
                }
            }

            my $entry;
            my $entry_counts = 0;
            if (scalar @unique_entries > 0) {
                log_info("TRANSLATION CANDIDATES:");
            }
            for my $i (0..$#unique_entries) {
                if ($repetitions[$i] == $entry_counts) {
                    undef $entry;
                } elsif ($repetitions[$i] > $entry_counts) {
                    $entry_counts = $repetitions[$i];
                    $entry = $unique_entries[$i];
                }
                log_info($unique_entries[$i]->{SRC_TEXT} . "  ->  " . $unique_entries[$i]->{TRG_TEXT} . "  (" . $repetitions[$i] . ")");
            }
            if (scalar @unique_entries > 0) {
                log_info("SELECTED TRANSLATION:    " . (defined $entry ? ($entry->{SRC_TEXT} . "  ->  " . $entry->{TRG_TEXT}) : "NONE"));
                log_info("********************************************************");
            }

            if (defined $entry) {
                my $entry_preceding_children = $entry->{SRC_PRECEDING_CHILDREN};
                my $entry_preceding_children_size = scalar @$entry_preceding_children;
                my $entry_following_children = $entry->{SRC_FOLLOWING_CHILDREN};
                my $entry_following_children_size = scalar @$entry_following_children;
                my @trg_children = $trg_tnode->get_children({ordered=>1});
                my $from = $preceding_children_size - $entry_preceding_children_size;
                my $to = $preceding_children_size + $entry_following_children_size - 1;
                for my $i ($from..$to) {
                    $trg_children[$i]->remove();
                }
                $self->add_children($trg_tnode, $entry->{TRG_PRECEDING_CHILDREN}, 1);
                $self->add_children($trg_tnode, $entry->{TRG_FOLLOWING_CHILDREN}, 0);
                $trg_tnode->set_t_lemma($entry->{TRG_LEMMA});
                $trg_tnode->set_t_lemma_origin('dict-TrLApplyTbxDictionary');
            }
        }
    }

    foreach my $tnode ($trg_tnode->get_children({ordered => 1})) {
        $self->process_tnode($tnode);
    }
    return;
}


sub add_children {
    my ($self, $parent, $children, $preceding) = @_;
    my $size = scalar @$children;
    for my $i (0..$size-1) {
        my $child = ${$children}[$preceding ? $i : $size - $i - 1];
        my $new_child = $parent->create_child(
            {
                t_lemma_origin => 'dict-TrLApplyTbxDictionary',
                formeme_origin => 'dict-TrLApplyTbxDictionary'
            }
        );
        foreach my $attr_name (@CHILDREN_ATTRIBUTES) {
            my $attr_value = $child->get_attr($attr_name);
            if (defined $attr_value) {
                $new_child->set_attr($attr_name, $attr_value);
            }
        }
        if ($preceding) {
            $new_child->shift_before_node($parent);
        } else {
            $new_child->shift_after_node($parent);
        }
        my @preceding_children = $child->get_children({preceding_only=>1});
        my @following_children = $child->get_children({following_only=>1});
        $self->add_children($new_child, \@preceding_children, 1);
        $self->add_children($new_child, \@following_children, 0);
    }
}


sub match {
    my ($self, $x_children, $y_children) = @_;
    my $size = scalar @$x_children;
    if ($size != scalar @$y_children) {
        return 0;
    }
    if ($size == 0) {
        return 1;
    }
    for my $i (0..$size-1) {
        my $x_child = ${$x_children}[$i];
        my $y_child = ${$y_children}[$i];
        foreach my $attr_name (@CHILDREN_ATTRIBUTES) {
            my $x_attr_value = $x_child->get_attr($attr_name);
            my $y_attr_value = $y_child->get_attr($attr_name);
            my $match = (!(defined $x_attr_value) && !(defined $y_attr_value)) || (defined $x_attr_value && defined $y_attr_value && $x_attr_value eq $y_attr_value);
            if (!$match) {
                return 0;
            }
        }
        my @x_preceding_children = $x_child->get_children({preceding_only=>1});
        my @y_preceding_children = $y_child->get_children({preceding_only=>1});
        my @x_following_children = $x_child->get_children({following_only=>1});
        my @y_following_children = $y_child->get_children({following_only=>1});
        if (not $self->match(\@x_preceding_children, \@y_preceding_children)) {
            return 0;
        }
        if (not $self->match(\@x_following_children, \@y_following_children)) {
            return 0;
        }
    }
    return 1;
}

1;

__END__

=over

=item Treex::Block::T2T::TrLApplyTbxDictionary

Try to apply some terminology dictionary in tbx format like the Microsoft one.

=back

=cut

# Copyright 2015 Mikel Artetxe
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

