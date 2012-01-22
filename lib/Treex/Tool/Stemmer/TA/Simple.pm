package Treex::Tool::Stemmer::TA::Simple;
use Moose;
use Treex::Core::Common;
use utf8;

my $verb_suffixes_file =
  "$ENV{'TMT_ROOT'}/share/data/models/simple_stemmer/ta/verb_suffixes.txt";
my $noun_suffixes_file =
  "$ENV{'TMT_ROOT'}/share/data/models/simple_stemmer/ta/noun_suffixes.txt";

# load verb suffixes
print STDERR "Loading Tamil verb suffixes ...\t\t";
our %verb_suffixes = load_suffixes($verb_suffixes_file);
my @suff = keys %verb_suffixes;
our @verb_suffixes_sorted = sort_hash_keys_by_length( \@suff );
print STDERR "Done\n";

# load noun suffixes
print STDERR "Loading Tamil noun suffixes ...\t\t";
our %noun_suffixes = load_suffixes($noun_suffixes_file);
@suff = keys %noun_suffixes;
our @noun_suffixes_sorted = sort_hash_keys_by_length( \@suff );
print STDERR "Done\n";

sub load_suffixes {
    my $file = shift;
    my %suffix_hash;
    open( RHANDLE, "<", $file ) or die "Error: cannot open file $file\n";
    my @data = <RHANDLE>;
    close RHANDLE;
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
    $sentence =~ s/\./ ./;

    # get word tokens
    my @words = split /\s+/, $sentence;

    foreach my $i ( 0 .. $#words ) {

        foreach my $n (@noun_suffixes_sorted) {
            if ( $words[$i] =~ /$n$/ ) {
                $words[$i] =~ s/$n$/ $noun_suffixes{$n}/;
                last;
            }
        }

        foreach my $s (@verb_suffixes_sorted) {
            if ( $words[$i] =~ /$s$/ ) {
                $words[$i] =~ s/$s$/ $verb_suffixes{$s}/;
                last;
            }
        }
    }
    my $stemmed_sentence = join " ", @words;
    return $stemmed_sentence;
}

sub stem_document {
    my ( $infile, $outfile ) = @_;
    open( RHANDLE, "<", $infile ) or die "Error: cannot open file $infile\n";
    my @data = <RHANDLE>;
    close RHANDLE;

    open( WHANDLE, ">", $outfile ) or die "Error: cannot open file $outfile\n";
    map {
        print WHANDLE Treex::Tool::Stemmer::TA::Simple::stem_sentence($_) . "\n"
    } @data;
    close WHANDLE;
}
1;

__END__

=pod

=head1 NAME

Treex::Tool::Stemmer::TA::Simple - rule based stemmer for Tamil

=head1 SYNOPSIS


=head2 Stem a sentence


 use Treex::Tool::Stemmer::TA::Simple
 my $sentence = "enakku patikkiRa pazakkam irukkiRaTu."
 my $stemmed_sentence = Treex::Tool::Stemmer::TA::Simple::stem_sentence($sentence);

=head2 Stem a document


use Treex::Tool::Stemmer::TA::Simple
Treex::Tool::Stemmer::TA::Simple::stem_document($infile, $outfile);

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
