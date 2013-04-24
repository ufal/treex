use Treex::Tool::Transliteration::TA;
use Test::More;
use utf8;

binmode STDIN,  ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

my @latin_str = ( 'kAtu',         'malai',     'vItu' );
my @utf8_str  = ( 'காடு', 'மலை', 'வீடு' );

my $transliterator =
  Treex::Tool::Transliteration::TA->new( use_enc_map => 'utf8_2_latin' );

# test - utf8 to latin conversion
foreach my $i ( 0 .. $#utf8_str ) {
	my $out_string = $transliterator->transliterate_string( $utf8_str[$i] );
	ok( $out_string eq $latin_str[$i], "$utf8_str[$i] => $out_string" );
}

# test - latin to utf8 conversion
$transliterator->set_enc_map('latin_2_utf8');
foreach my $i ( 0 .. $#latin_str ) {
	my $out_string = $transliterator->transliterate_string( $latin_str[$i] );
	ok( $out_string eq $utf8_str[$i], "$latin_str[$i] => $out_string" );
}
done_testing();
