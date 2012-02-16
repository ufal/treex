package Treex::Tool::Stemmer::TA::Simple;
use utf8;
use Moose;
use autodie;
use Treex::Core::Common;
use Treex::Core::Resource;

my $data_dir = 'data/models/simple_stemmer/ta';
my $verb_suffixes_file = require_file_from_share("$data_dir/verb_suffixes.txt");
my $noun_suffixes_file = require_file_from_share("$data_dir/noun_suffixes.txt");

# load verb suffixes
log_info 'Loading Tamil verb suffixes...';
our %verb_suffixes = load_suffixes($verb_suffixes_file);
my @suff = keys %verb_suffixes;
our @verb_suffixes_sorted = sort_hash_keys_by_length( \@suff );

# load noun suffixes
log_info "Loading Tamil noun suffixes...";
our %noun_suffixes = load_suffixes($noun_suffixes_file);
@suff = keys %noun_suffixes;
our @noun_suffixes_sorted = sort_hash_keys_by_length( \@suff );

# clitics {TAn, E, O, A, um}
our $clitics = q{TAn};

# postpositions
our $postpositions =
  q{itamiruwTu|TotarpAka|TotarpAna|iliruwTu|maTTiyil|mUlamAka|TotarwTu|uLLAkavE|
vaziyAka|eTirAna|illAmal|itaiyil|kuRiTTa|kuRiTTu|muRaiyE|paRRiya|allATa|allATu|
arukil|cArpil|cArwTa|cErTTu|cErwTa|eTiril|illATa|iruwTa|iruwTu|itaiyE|kuRiTT|
KuRiTT|mElAna|mITAna|munnAl|pinnar|piRaku|Tavira|utpata|arukE|koNta|mITum|mUlam|
munpu|munpE|muTal|paRRi|pOnRa|varai|Akac|Akak|Akap|anRu|aRRa|inRi|itam|kIzE|mElE
|mITu|otti|pati|kUta|pOla|pOTu|uLLa|utan|vita|Aka|Ana|kIz|mEl|Otu};

sub load_suffixes {
    my $file = shift;
    my %suffix_hash;
    open( my $RHANDLE, '<', $file );
    my @data = <$RHANDLE>;
    close $RHANDLE;
    foreach my $line (@data) {
        chomp $line;
        $line =~ s/(^\s+|\s+$)//;
        next if ( $line =~ /^\s*$/ );
        next if ( $line =~ /^#/ );
        my @suff_split = split /\s*:\s*/, $line;
        next if ( scalar(@suff_split) != 2 );
        $suffix_hash{ $suff_split[0] } = $suff_split[1];
    }
    return %suffix_hash;
}

sub sort_hash_keys_by_length {
    my $suffix_ref = shift;
    my @suffixes   = @{$suffix_ref};
    my %suffix_hash;
    map { $suffix_hash{$_} = length($_) } @suffixes;
    my @keys_sorted =
      sort { $suffix_hash{$b} <=> $suffix_hash{$a} } keys %suffix_hash;
    return @keys_sorted;
}

sub stem_sentence {
    my $sentence = shift;
    chomp $sentence;

    $sentence =~ s/(^\s+|\s+$)//;

    return '' if ( $sentence eq '' );

    # at least "comma"" and "." has to be separated from the original
    $sentence =~ s/\.$/ ./;
    $sentence =~ s/,/ ,/g;

    # preserve the existing "+" symbols to avoid confusion with suffixes
    $sentence =~ s/\+/<<+>>/g;

    # take out the sandhis (ex: patikkac => patikka +c)
    $sentence =~ s/(a|u)(k|c|T|p)(\s|\t)/$1 +$2 /g;

    # split the clitics from word forms
    $sentence =~ s/([a-zA-Z])($clitics)(\s|\t)/$1 +$2 /g;

    # split the postpositions from word forms
    $sentence =~ s/([a-zA-Z])($postpositions)(\s|\t)/$1 +$2 /g;

    # take out the sandhis (ex: patikkac => patikka +c)
    $sentence =~ s/(a|u)(k|c|T|p)(\s|\t)/$1 +$2 /g;

    # get word tokens
    my @words = split /\s+/, $sentence;

    # words after application of noun suffixes separation
    my @words_after_n;

    foreach my $i ( 0 .. $#words ) {
        my $len_w = length $words[$i];
        if ( $len_w > 4 ) {
            my $change = 0;
            foreach my $n (@noun_suffixes_sorted) {
                my $len_n = length $n;
                next if ( $len_n == $len_w );
                if ( $words[$i] =~ /$n$/ ) {
                    $words[$i] =~ s/$n$/ $noun_suffixes{$n}/;
                    $words[$i] =~ s/(^\s+|\s+$)//;
                    my @newwords = split /\s+/, $words[$i];
                    push @words_after_n, @newwords;
                    $change = 1;
                    last;
                }
            }
            if ( !$change ) {
                push @words_after_n, $words[$i];
            }
        }
        else {
            push @words_after_n, $words[$i];
        }
    }

    #print "words before= " . join ("\t:", @words_after_n) . "\n";
    foreach my $i ( 0 .. $#words_after_n ) {
        my $len_w = length $words_after_n[$i];
        if ( $len_w > 4 ) {
            foreach my $s (@verb_suffixes_sorted) {
                my $len_v = length $s;
                last if ( $words_after_n[$i] =~ /^\+/ );
                next if ( $len_v == $len_w );
                if ( $words_after_n[$i] =~ /$s$/ ) {
                    $words_after_n[$i] =~ s/$s$/ $verb_suffixes{$s}/;
                    last;
                }
            }
        }
    }
    my $stemmed_sentence = join " ", @words_after_n;
    return $stemmed_sentence;
}

sub restore_sentence {
    my $sentence = shift;
    my $restored_sentence;
    chomp $sentence;

    $sentence =~ s/(^\s+|\s+$)//;

    return '' if ( $sentence eq '' );

    my @words = split /\s+/, $sentence;
    my @st1;
    foreach my $i ( 0 .. $#words ) {
        my $st1_len = scalar(@st1);
        if ( $words[$i] =~ /^\+/ ) {
            if ( $st1_len > 0 ) {
                $words[$i] =~ s/^\+//;
                $st1[$#st1] = $st1[$#st1] . $words[$i];
            }
            else {
                push @st1, $words[$i];
            }
        }
        else {
            push @st1, $words[$i];
        }
    }
    $restored_sentence = join " ", @st1;

    # bring back the original "+" symbols in the document
    $restored_sentence =~ s/<<\+>>/+/g;

    return $restored_sentence;
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Tool::Stemmer::TA::Simple - rule based stemmer for Tamil

=head1 SYNOPSIS

 use Treex::Tool::Stemmer::TA::Simple;
 my $sentence = "enakku patikkiRa pazakkam irukkiRaTu.";
 print Treex::Tool::Stemmer::TA::Simple::stem_sentence($sentence);
 #ena +kku pati +kkiR +a pazakkam iru +kkiR +aTu .

=head1 SUBROUTINES

=head2 C<my $stemmed = stem_sentence($raw_plain_text)>

Returns a string where stems are separated from the suffixes.
A plus sign is added to the beginning of each suffix,
so it is possible to revert it.
One token can have zero, one or more suffixes.
Plus sign in the raw text is encoded as C<< <<\+>>> >>.

=head2 C<my $raw_plain_text = stem_sentence($stemmed)>

The inverse operation to C<stem_sentence>.

=head1 REQUIRED SHARED FILES

C<data/models/simple_stemmer/ta/{verb,noun}_suffixes.txt>

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
