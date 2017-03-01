package Treex::Block::HamleDT::TA::ReadDetokenizedSentences;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';
# The following libraries are currently available in the old part of TectoMT.
use translit::brahmi; # Dan's transliteration tables for Brahmi-based scripts

has 'table' => (isa => 'HashRef', is => 'ro', default => sub {{}});
has 'maxl' => (isa => 'Int', is => 'rw', default => 1, writer => '_set_maxl');
has 'scientific' => (isa => 'Bool', is => 'rw', default => 1); # romanization type



has 'from' =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => 'Path to the file with the sentences, one sentence per line.'
);

has 'sentences' =>
(
    is            => 'ro',
    isa           => 'ArrayRef',
    required      => 1,
    default       => sub {[]}
);



#------------------------------------------------------------------------------
# Reads the detokenized sentences. It reads them all at once. The assumption is
# that the document is not too large and that we can keep it in memory. This is
# definitely true for the first version of the Tamil Treebank.
#------------------------------------------------------------------------------
sub BUILD
{
    my $self = shift;
    my $from = $self->from();
    my $sentences = $self->sentences();
    open(SENT, $from) or log_fatal("Cannot read $from: $!");
    binmode(SENT, ':utf8');
    while(<SENT>)
    {
        chomp();
        push(@{$sentences}, $_);
    }
    close(SENT);
    # Set up transliteration table.
    my $table = $self->table();
    my $scientific = $self->scientific(); # type of romanization
    # 0xB80: Tamil script.
    translit::brahmi::inicializovat($table, 2944, $scientific ? 2 : 0);
    # Figure out and return the maximum length of an input sequence.
    my $maxl = 1; map {$maxl = max2($maxl, length($_))} (keys(%{$table}));
    $self->_set_maxl($maxl);
}



#------------------------------------------------------------------------------
# Takes detokenized sentences one at a time, and stores them with the bundles.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $sentences = $self->sentences();
    my $next_sentence = shift(@{$sentences});
    if(defined($next_sentence))
    {
        # The source sentences supplied by Loganathan are partially tokenized. Periods are separate tokens but commas are attached to the previous word.
        # We actually want full tokenization at this level, i.e. all punctuation symbols are separate tokens.
        # The 'Detokenized' in the name of this block refers to orthographic words that are split to multiple tree nodes.
        $next_sentence =~ s/(\S),/$1 ,/g;
        $zone->set_sentence($next_sentence);
        # We want the detokenized sentence to appear as a comment in the CoNLL-U output.
        # This is a temporary measure before we manage to represent everything as fused words
        # and with the no_space_after attribute.
        my $wild = $zone->get_bundle()->wild();
        my $comment = $wild->{comment};
        if(defined($comment) && $comment ne '')
        {
            $comment .= "\n";
        }
        $comment .= 'full_sent '.$next_sentence;
        my $table = $self->table();
        my $maxl = $self->maxl();
        my $translit = translit::prevest($table, $next_sentence, $maxl);
        $comment .= "\nfull_sent_translit $translit";
        $wild->{comment} = $comment;
        # Find alignment between orthographic and syntactic words.
        my @nodes = $zone->get_atree()->get_descendants({'ordered' => 1});
        my @src = split(/\s+/, $next_sentence);
        my @tgt = map {$_->form()} (@nodes);
        if(scalar(@src) != scalar(@tgt))
        {
            my @alignment = $self->find_alignment(\@src, \@tgt);
            my $debugging_needed = 0;
            if(scalar(@alignment) != scalar(@tgt))
            {
                my $na = scalar(@alignment);
                my $nt = scalar(@tgt);
                log_warn("Alignment too short or too long: nt=$nt; na=$na.");
                $debugging_needed = 1;
            }
            my @astring;
            for(my $j = 0; $j <= $#alignment; $j++)
            {
                if(defined($alignment[$j]{index}))
                {
                    push(@astring, "$alignment[$j]{index}-$j");
                }
                else
                {
                    push(@astring, "$alignment[$j]{index0}..$alignment[$j]{index1}-$j");
                    $debugging_needed = 1;
                }
            }
            if($debugging_needed)
            {
                log_info('SRC: '.join(' ', @src));
                log_info('TGT: '.join(' ', @tgt));
                log_info('ALI: '.join(' ', @astring));
            }
            # Convert the start, end and form attributes of alignments to the wild attributes that the CoNLL-U writer expects.
            for(my $j = 0; $j <= $#alignment; $j++)
            {
                # Skip target words that correspond to just one source word. Only the interesting ones have 'start' defined.
                if(defined($alignment[$j]{start}))
                {
                    my $wild = $nodes[$j]->wild();
                    $wild->{fused} = $alignment[$j]{start}==$j ? 'start' : $alignment[$j]{end}==$j ? 'end' : 'middle';
                    $wild->{fused_end} = $alignment[$j]{end}+1; # ord starts at 1
                    $wild->{fused_form} = $alignment[$j]{form};
                }
            }
        }
    }
    else
    {
        log_warn('Bad synchronization. There is no remaining detokenized sentence for this bundle.');
    }
}



#------------------------------------------------------------------------------
# Takes two arrays of words, one from the original sentence and the other from
# the nodes of the tree. Assumes that the first sequence is shorter or
# or identical to the second sequence. If it is shorter, then it is because
# some surface tokens have been split to syntactic words. It further assumes
# (but it is probably not guaranteed) that every word type is either never
# split or it is always split the same way. The function finds word alignment
# between the two arrays. The result is array of pairs (hashes) index-word.
# Each pair corresponds to a target word, and it gives the index and form of
# its corresponding source word.
#------------------------------------------------------------------------------
sub find_alignment
{
    my $self = shift; # but this function is static
    my $src = shift; # reference to source array
    my $tgt = shift; # reference to target array
    log_fatal('Splitting tokens into syntactic words cannot yield fewer words than in the original sentence.') if(scalar(@{$tgt}) < scalar(@{$src}));
    # If the two arrays have the same length, assume that their contents is also identical: no splitting could have occurred.
    my @result;
    if(scalar(@{$tgt}) == scalar(@{$src}))
    {
        for(my $i = 0; $i <= $#{$src}; $i++)
        {
            push(@result, {'index' => $i, 'form' => $src->[$i]});
        }
    }
    else # there is at least one split token and length($src) < length($tgt)
    {
        my $i = 0; # index to $src
        my $j = 0; # index to $tgt
        while(1)
        {
            # Find the next split (i.e. unmatched token).
            while($i <= $#{$src} && $src->[$i] eq $tgt->[$j])
            {
                push(@result, {'index' => $i, 'form' => $src->[$i]});
                $i++;
                $j++;
            }
            # Leave the main loop if there were no more splits.
            last if($i >= $#{$src});
            # The current words do not match. Look for the next match, if any.
            # Try to find the next source word in the target sequence.The exact alignment is not known.
            my $k = $i+1;
            for(; $k <= $#{$src}; $k++)
            {
                my $l = $j+($k-$i);
                while($l <= $#{$tgt} && $src->[$k] ne $tgt->[$l])
                {
                    $l++;
                }
                # Did we find a match?
                if($l <= $#{$tgt} && $src->[$k] eq $tgt->[$l])
                {
                    # If we found a match after skipping just one source word, all the skipped target words correspond to the unmatched source word.
                    # If the number of skipped source words is half of the number of skipped target words, we will distribute the target words uniformly.
                    # Otherwise we have a sequence of split tokens and we do not know the exact pairing.
                    # Note that we cannot rely on the source word being concatenation of the target words. Although it is often the case,
                    # it is not directly visible because of how the Tamil script handles vowels in the beginning and in the middle of a word.
                    # However, we can (in Tamil) rely on the first target word having a common prefix with the corresponding source word.
                    my $nskipsrc = $k-$i;
                    my $nskiptgt = $l-$j;
                    if($nskipsrc==1)
                    {
                        for(my $o = $j; $o < $l; $o++)
                        {
                            push(@result, {'index' => $i, 'form' => $src->[$i], 'start' => $j, 'end' => $l-1});
                        }
                    }
                    elsif($nskiptgt == $nskipsrc*2)
                    {
                        for(my $o = $i; $o < $k; $o++)
                        {
                            push(@result, {'index' => $o, 'form' => $src->[$o], 'start' => $j+($o-$i)*2, 'end' => $j+($o-$i)*2+1});
                            push(@result, {'index' => $o, 'form' => $src->[$o], 'start' => $j+($o-$i)*2, 'end' => $j+($o-$i)*2+1});
                        }
                    }
                    else
                    {
                        log_warn('Two or more adjacent source tokens are split to syntactic words. Trying to estimate the alignment...');
                        # In most cases I have observed, there are two source words and five to six target words.
                        # Hence we just have to look for a prefix of the second source word.
                        # In one case there were three source words and seven target words.
                        my $solved = 1;
                        my @matches;
                        for(my $p = $i+1; $p < $k; $p++)
                        {
                            # Examine all candidates and find the longest match. Otherwise if the word begins with 'u', we would wrongly grab the first 'um' suffix.
                            my $match_index = undef;
                            my $match_length = undef;
                            for(my $o = $j+1; $o < $l; $o++)
                            {
                                my $prefix_candidate = $tgt->[$o];
                                my $match = 0;
                                while(length($prefix_candidate) > 0)
                                {
                                    # Stop shortening the prefix if we already know about an equal or longer match.
                                    if(defined($match_length) && length($prefix_candidate) <= $match_length)
                                    {
                                        last;
                                    }
                                    if($src->[$p] =~ m/^$prefix_candidate/)
                                    {
                                        $match = 1;
                                        last;
                                    }
                                    $prefix_candidate =~ s/.$//;
                                }
                                if($match)
                                {
                                    if(!defined($match_length) || $match_length < length($prefix_candidate))
                                    {
                                        log_warn("Match: $src->[$p] = $tgt->[$o]");
                                        $match_index = $o;
                                        $match_length = length($prefix_candidate);
                                    }
                                }
                            }
                            if(defined($match_index))
                            {
                                push(@matches, $match_index);
                            }
                            else
                            {
                                $solved = 0;
                                last;
                            }
                        }
                        # If we found prefix(es) of the second (and all subsequent) source word(s), we are all set.
                        if($solved)
                        {
                            my $o = $j;
                            push(@matches, $l);
                            for(my $p = $i; $p < $k; $p++)
                            {
                                my $o0 = $o;
                                for(; $o < $matches[$p-$i]; $o++)
                                {
                                    push(@result, {'index' => $p, 'form' => $src->[$p], 'start' => $o0, 'end' => $matches[$p-$i]-1});
                                }
                            }
                        }
                        else
                        {
                            # As of Tamil UD 1.2, the data does not contain anything so complex that we would end up here.
                            log_fatal('Cannot handle complex alignment between orthographic and syntactic words.');
                            my @forms = @{$src}[$i..($k-1)];
                            for(my $o = $j; $o < $l; $o++)
                            {
                                push(@result, {'index0' => $i, 'index1' => $k-1, 'forms' => \@forms});
                            }
                        }
                    }
                    # Now we are synchronized again.
                    $i = $k;
                    $j = $l;
                    last;
                }
            }
            # If we got here via the 'last' command, we are synchronized and at least one word remains both in source and target.
            # If we left the loop because $k==$#{$src}, we failed to find a match for any remaining source word.
            if($k >= $#{$src})
            {
                my @forms;
                if($k-$i > 1)
                {
                    log_warn('Two or more adjacent source tokens are split to syntactic words. The exact alignment is not known.');
                    @forms = @{$src}[$i..($k-1)];
                }
                for(my $o = $j; $o <= $#{$tgt}; $o++)
                {
                    if($k-$i > 1)
                    {
                        push(@result, {'index0' => $i, 'index1' => $k-1, 'forms' => \@forms});
                    }
                    else
                    {
                        push(@result, {'index' => $i, 'form' => $src->[$i]});
                    }
                }
                last;
            }
        }
    }
    return @result;
}



#------------------------------------------------------------------------------
# Returns maximum of two values.
#------------------------------------------------------------------------------
sub max2
{
    my $a = shift;
    my $b = shift;
    return $a>=$b ? $a : $b;
}



1;

=over

=item Treex::Block::HamleDT::TA::ReadDetokenizedSentences

The Tamil Treebank 0.1 lacks information needed to reconstruct the original
pre-tokenization text. Besides punctuation separated from words, tokenization
occasionally also involves splitting words to smaller units (syntactic words).
Loganathan has written a script that reconstructs the original sentences and
provided the output in text files, one sentence per line.

This block reads Loganathan's reconstructed files, then takes the next sentence
for each bundle it processes, and stores the sentence in the bundle's C<sentence>
attribute. Hence it combines the detokenized sentences with the trees.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2015 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
