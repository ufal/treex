package Treex::Block::W2A::JA::TagMeCab;
use 5.010;
use feature qw(switch);
use Moose;
use Treex::Core::Common;
use Encode;
extends 'Treex::Core::Block';
use MeCab;

has _form_corrections => (
    is      => 'ro',
    isa     => 'HashRef[Str]',
    default => sub {
        {
            q(``) => q("),
            q('') => q("),
        }
    },
    documentation => q{Possible changes in forms done by tagger},
);

sub _revert_form {    #taken from Lingua::EN::Tagger
    my $self = shift;
    my %args = @_;
    my $new  = $args{new};
    return $self->_form_corrections->{$new} // $new;  #/
}


sub process_zone {


#Lingua Wrapper Code
    my ( $self, $zone ) = @_;

    

    # get the source sentence
    my $sentence = $zone->sentence;
    log_fatal("No sentence in zone") if !defined $sentence;
    log_fatal(qq{There's already atree in zone}) if $zone->has_atree();
    log_debug("Processing sentence: $sentence"); #'

    my $result = "";

    my $model = new MeCab::Model();
    my $tagger = $model->createTagger();

    my $debug;
    
    # adds tags and modifies the output format of MeCab tagger
    for (my $m = $tagger->parseToNode($sentence); $m; $m = $m->{next}) {
    	my $wordform = decode('utf-8', $m->{surface});
    	my @features = split /,/, decode('utf-8', $m->{feature});
        
        #TODO: should use whole IPADIC tagset (or JDEPP parser is bound to make mistakes sometimes)
        my $bTag = $features[0].'_'.$features[1];
        my $lemma = $features[6];      

    	if ($bTag !~ "BOS" && $bTag !~ "空白") {
            
            $lemma = $wordform if $lemma eq '*';

            $debug = $wordform if $bTag =~ "サ変接続";

            $bTag =~ s{\_\*}{};
            $bTag =~ s{／.*}{};
            $bTag =~ s{^(.+)$}{<$1>};
            my $eTag = $bTag;
            $eTag =~ s{<}{</};
	    $result .= ' '.$bTag.$wordform.$eTag.$lemma;
            
    	}
    }
    $result =~ s{^\s+}{};

    #split on whitespace, tags nor tokens doesn't contain spaces
    my @tagged = split /\s+/,  $result;

    # create a-tree
    my $a_root    = $zone->create_atree();
    my $tag_regex = qr{
        <(\w+)> #<tag>
        ([^<]+) #form
        </\1>   #</tag>
        (.+)    #lemma
        }x;
    my $space_start = qr{^\s+};
    my $ord         = 1;
    foreach my $tag_pair (@tagged) {
        if ( $tag_pair =~ $tag_regex ) {
            my $form = $self->_revert_form( new => $2 );

            my $tag = $1; 
            $tag =~ s{^<(\w+)>.$}{$1};

            my $lemma = $3;
 
            if ( $sentence =~ s/^\Q$form\E// ) {

                #check if there is space after word
                my $no_space_after = $sentence =~ m/$space_start/ ? 0 : 1;
                if ( $sentence eq q{} ) {
                    $no_space_after = 0;
                }

                #delete it
                $sentence =~ s{$space_start}{};
		
                # and create node under root
                $a_root->create_child(
                    form           => $form,
                    tag            => $tag,
                    lemma          => $lemma,
                    no_space_after => $no_space_after,
                    ord            => $ord++,
                );
            }
            else {
                log_fatal("Mismatch between tagged word and original sentence: Tagged: $form. Original: $sentence.");
            }
        }
        else {
            log_fatal("Incorrect output format from MeCab: $tag_pair debug: $debug");
        }

    }
    return 1;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::TagMeCab

=head1 DESCRIPTION

Each sentence is tokenized and tagged using C<MeCab> (Ipadic POS tags).
Ipadic tagset uses hierarchical tags. This module uses only basic tag and first subtag layer if available.
Tags are in kanji, in the future they should be replaced by Romanized tags or their abbreviations (other japanese treex modules should be modified accordingly).

=head1 AUTHORS

Dusan Varis


