package Treex::Block::T2T::TbxParser;
use utf8;
use XML::LibXML;
use Treex::Core::Common;

Readonly my %POS2MPOS => (
    'Adjective' => 'adj',
    'Adverb' => 'adv',
    'Noun' => 'noun',
#   'Other' => '',
    'Proper Noun' => 'noun',
    'Verb' => 'verb');

Readonly my %POS2SEMPOS => (
    'Adjective' => 'adj',
    'Adverb' => 'adv',
    'Noun' => 'n',
#   'Other' => '',
    'Proper Noun' => 'n',
    'Verb' => 'v');

sub parse_tbx {
    my ($self, $dictionary, $src_id, $trg_id) = @_;
    my @entries;
    my $parser = XML::LibXML->new();
    my $file = Treex::Core::Resource::require_file_from_share($dictionary);
    my $doc = $parser->parse_file($file)->getDocumentElement;
    foreach my $term ($doc->findnodes('//termEntry')) {
        my $src = $term->findnodes("langSet[\@xml:lang='" . $src_id . "']")->shift;
        my $trg = $term->findnodes("langSet[\@xml:lang='" . $trg_id . "']")->shift;
        my $src_text = $src->findnodes("*/*/term")->shift->textContent;
        my $trg_text = $trg->findnodes("*/*/term")->shift->textContent;
        my $src_pos = $src->findnodes("*/*/termNote[\@type='partOfSpeech']")->shift->textContent;
        my $trg_pos = $trg->findnodes("*/*/termNote[\@type='partOfSpeech']")->shift->textContent;
        my $src_mpos = $POS2MPOS{$src_pos};
        my $trg_mpos = $POS2MPOS{$trg_pos};
        my $src_sempos = $POS2SEMPOS{$src_pos};
        my $trg_sempos = $POS2SEMPOS{$trg_pos};
        if (defined $src_mpos and defined $trg_mpos and defined $src_sempos and defined $trg_sempos) {
            my $entry = {
                SRC_TEXT                =>  $src_text,
                SRC_MPOS                =>  $src_mpos,
                SRC_SEMPOS              =>  $src_sempos,
                TRG_TEXT                =>  $trg_text,
                TRG_MPOS                =>  $trg_mpos,
                TRG_SEMPOS              =>  $trg_sempos,
            };
            push(@entries, $entry);
        }
    }
    return @entries;
}
