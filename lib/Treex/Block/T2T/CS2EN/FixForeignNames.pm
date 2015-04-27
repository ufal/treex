package Treex::Block::T2T::CS2EN::FixForeignNames;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'lexicon_file' => ( isa => 'Str', is => 'ro', default => 'data/models/lexicon/en/people.cs-en.noid.tsv' );


has '_lexicon' => ( isa => 'HashRef', is => 'ro', lazy_build => 1, builder => '_build_lexicon' );


sub _build_lexicon {
    
    my ($self) = @_;
    
    my $lex_file = $self->lexicon_file;
    if (not -f $lex_file){
        $lex_file = Treex::Core::Resource::require_file_from_share($lex_file);
    }
    my %lex = ();
    
    open(my $fh, '<:utf8', ( $lex_file ) );
    while (my $line = <$fh>){
        chomp $line;
        my ($key, $val) = split /\t/, $line;
        $lex{lc $key} = $val;
    }
    close($fh);
    return \%lex;    
}

sub process_tnode {
    my ($self, $t_node) = @_;
    
    # skip those that were translated
    return if (($t_node->t_lemma // '') !~ /^\p{Lu}\p{Ll}/);
    return if ($t_node->get_attr('translation_model/t_lemma_variants'));
    
    my $transl = $self->_lexicon->{lc $t_node->t_lemma};
    if ($transl){
        $t_node->set_t_lemma($transl);
    }
    
    # TODO smazat diakritiku ??
         
}

1;