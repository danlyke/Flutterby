package Flutterby::Confignew;

sub load
  {
    return
      {
       -database => 'DBI:Pg:dbname=flutterbycms',
       -databaseuser => 'danlyke',
       -databasepass => 'danlyke',
       -htmlpath => 'flutterby_cms/html/',
       -classcolortags => 		   
       {
	'body' => 
	{
	 'wb' => 
	 {
	  'text' => '#AAFFFF',
	  'bgcolor' => '#000000',
	  'link' => '#aaaaff',
	  'vlink' => '#aa66ff',
	 },
	 'pw' =>
	 {
	  'text' => '#AAFFFF',
	  'bgcolor' => '#000000',
	  'link' => '#aaaaff',
	  'vlink' => '#aa66ff',
	 },
	 'bw' =>
	 {
	  'text' => '#000000',
	  'bgcolor' => '#ffffff',
	  'link' => '#0000ff',
	  'vlink' => '#551a8b',
	 },
	 'pb' =>
	 {
	  'text' => '#000000',
	  'bgcolor' => '#ffffff',
	  'link' => '#0000ff',
	  'vlink' => '#551a8b',
	 },
	},
	'flutterbybodystandard' =>
	{
	 'wb' => 
	 {
	  'text' => '#AAFFFF',
	  'bgcolor' => '#000000',
	  'link' => '#aaaaff',
	  'vlink' => '#aa66ff',
	 },
	 'pw' => 
	 {
	  'text' => '#AAFFFF',
	  'bgcolor' => '#000000',
	  'link' => '#aaaaff',
	  'vlink' => '#aa66ff',
	 },
	 'bw' => 
	 {
	  'text' => '#000000',
	  'bgcolor' => '#ffffff',
	  'link' => '#0000ff',
	  'vlink' => '#551a8b',
	 },
	 'pb' =>
	 {
	  'text' => '#000000',
	  'bgcolor' => '#ffffff',
	  'link' => '#0000ff',
	  'vlink' => '#551a8b',
	 },
	},
       },
      };
  }

1;


