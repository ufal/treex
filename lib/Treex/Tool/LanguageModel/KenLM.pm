package Treex::Tool::LanguageModel::KenLM;
use Moose;
use ProcessUtils;

has language_model => (
is      => 'ro',
isa     => 'Str',
default => '/net/work/people/green/LanguageModels/txt.lm'
);

my $bindir = "/ha/work/people/green/Code/tectomt/share/installed_tools/kenlm";

my $language_model;

sub BUILD {
  my ($self) = @_;
  my $query = "./query " . $self->language_model;
  my ( $reader, $writer ) = ProcessUtils::bipipe("cd $bindir; $query ");
  $self->{reader} = $reader;
  $self->{writer} = $writer;
  
  bless $self;
  }
  
sub query {
  my ( $self, $phrase ) = @_;
  my $writer = $self->{writer};
  my $reader = $self->{reader};
  
  my $output = "";
  my $value  = 0;
  if ( length($phrase) > 0 ) {
    print $writer "$phrase\n";
    $output = <$reader>;
    my $end   = index( $output, "OOV" );
    my $start = index( $output, "Total:" );
    if ( $start > 0 ) {
      $value = substr( $output, $start + 7, ( $end - $start - 7 ) );
      }
      else {
	print " Whole Sentence failed\n";
	}
	}
	return $value;
	}
	
	1;
	
	__END__
	  